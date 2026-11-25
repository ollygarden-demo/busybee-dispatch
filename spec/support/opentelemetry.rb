# Traces the suite into the CI pipeline trace when the workflow passes TRACEPARENT.
return unless ENV["TRACEPARENT"]

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

OpenTelemetry::SDK.configure

# opentelemetry-api has no environment-variable carrier yet, so extract from a hash built from ENV.
pipeline_context = OpenTelemetry.propagation.extract(
  { "traceparent" => ENV["TRACEPARENT"], "tracestate" => ENV["TRACESTATE"], "baggage" => ENV["BAGGAGE"] }.compact
)
tracer = OpenTelemetry.tracer_provider.tracer("busybee-dispatch-rspec")

RSpec.configure do |config|
  suite_span = nil
  suite_context = nil

  config.before(:suite) do
    suite_span = tracer.start_span("rspec", with_parent: pipeline_context, attributes: { "test.suite.name" => "rspec" })
    suite_context = OpenTelemetry::Trace.context_with_span(suite_span, parent_context: pipeline_context)
  end

  config.around(:example) do |example|
    OpenTelemetry::Context.with_current(suite_context) do
      tracer.in_span(example.full_description, attributes: { "test.case.name" => example.full_description }) do |span|
        example.run
        if example.exception
          span.set_attribute("test.case.result.status", "fail")
          span.record_exception(example.exception)
          span.status = OpenTelemetry::Trace::Status.error(example.exception.class.name)
        else
          span.set_attribute("test.case.result.status", "pass")
        end
      end
    end
  end

  config.after(:suite) do
    failed = RSpec.configuration.reporter.failed_examples.any? || RSpec.world.non_example_failure
    suite_span.set_attribute("test.suite.run.status", failed ? "failure" : "success")
    suite_span.status = OpenTelemetry::Trace::Status.error("test failures") if failed
    suite_span.finish

    flushed = OpenTelemetry.tracer_provider.force_flush
    OpenTelemetry.tracer_provider.shutdown
    raise "exporting test spans failed" unless flushed == OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end
