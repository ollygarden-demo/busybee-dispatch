ENV["OTEL_TRACES_SAMPLER_ARG"] ||= "1"
require "rails_helper"
require "opentelemetry/sdk/trace/export/in_memory_span_exporter"
require "opentelemetry/sdk/metrics/export/in_memory_metric_pull_exporter"
require "opentelemetry/sdk/logs/export/in_memory_log_record_exporter"

RSpec.describe BusybeeDispatch::Telemetry, type: :request do
  before do
    @span_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    OpenTelemetry.tracer_provider.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@span_exporter)
    )
    @metric_exporter = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
    OpenTelemetry.meter_provider.add_metric_reader(@metric_exporter)
    @log_exporter = OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new
    OpenTelemetry.logger_provider.add_log_record_processor(
      OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(@log_exporter)
    )
  end

  it "creates a business span and propagates W3C context through an SQS carrier" do
    carrier = {}
    parent_span = nil

    described_class.in_span("delivery.assignment", attributes: { "busybee.workflow" => "assignment" }) do |span|
      parent_span = span
      OpenTelemetry.propagation.inject(carrier)
    end

    sqs_message = Struct.new(:message_attributes).new(
      carrier.transform_values { |value| Struct.new(:string_value).new(value) }
    )
    described_class.with_extracted_context(described_class.sqs_carrier(sqs_message)) do
      described_class.in_span("busybee-deliveries receive", kind: :consumer) {}
    end

    spans = @span_exporter.finished_spans
    child = spans.find { |span| span.name == "busybee-deliveries receive" }
    expect(carrier.fetch("traceparent")).to match(/\A00-[0-9a-f]{32}-[0-9a-f]{16}-0[01]\z/)
    expect(child).not_to be_nil
    expect(child.parent_span_id).to eq(parent_span.context.span_id)
    expect(child.trace_id).to eq(parent_span.context.trace_id)
  end

  it "normalizes AWS message attribute values before W3C extraction" do
    traceparent = "00-#{'a' * 32}-#{'b' * 16}-01"
    value = Struct.new(:string_value).new(traceparent)
    message = Struct.new(:message_attributes).new({ "traceparent" => value })

    expect(described_class.sqs_carrier(message)).to eq("traceparent" => traceparent)
  end

  it "records bounded business metrics" do
    described_class.record_assignment(:assigned, 0.25)
    described_class.record_event(:created)
    @metric_exporter.pull

    names = @metric_exporter.metric_snapshots.map(&:name)
    expect(names).to include("busybee.assignment.attempts", "busybee.assignment.duration", "busybee.delivery.events")
  end

  it "configures a periodic metric reader with graceful SDK lifecycle support" do
    readers = OpenTelemetry.meter_provider.instance_variable_get(:@metric_readers)
    reader = readers.find { |candidate| candidate.is_a?(OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader) }

    expect(reader).not_to be_nil
    expect(reader.instance_variable_get(:@exporter)).to be_a(OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter)
    expect(reader.instance_variable_get(:@thread)).to be_alive
  end

  it "creates one server span with database descendants for an API request" do
    previous_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = "test-secret"
    token = JWT.encode(
      { sub: "telemetry-test", iss: "busybee-dispatch", aud: "busybee-api", exp: 1.hour.from_now.to_i },
      ENV.fetch("JWT_SECRET"),
      "HS256"
    )

    get "/api/v1/deliveries/#{SecureRandom.uuid}", headers: { "Authorization" => "Bearer #{token}" }

    server_spans = @span_exporter.finished_spans.select { |span| span.kind == :server }
    expect(response).to have_http_status(:not_found)
    expect(server_spans.size).to eq(1)
    expect(@span_exporter.finished_spans.any? { |span| span.parent_span_id == server_spans.first.span_id }).to be(true)
  ensure
    ENV["JWT_SECRET"] = previous_secret
  end

  it "does not create a server span for the health endpoint" do
    get "/health"

    expect(response).to have_http_status(:ok)
    expect(@span_exporter.finished_spans.none? { |span| span.kind == :server }).to be(true)
  end

  it "correlates existing Rails logs with the active span" do
    described_class.in_span("delivery.event.process") { Rails.logger.info("telemetry contract log") }
    record = @log_exporter.emitted_log_records.find { |entry| entry.body == "telemetry contract log\n" }

    expect(record).not_to be_nil
    expect(record.trace_id).not_to be_nil
    expect(record.span_id).not_to be_nil
  end
end
