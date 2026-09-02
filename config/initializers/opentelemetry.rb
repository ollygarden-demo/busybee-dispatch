# Keep the local demo useful without making telemetry a runtime dependency.
ENV["OTEL_SERVICE_NAME"] ||= "busybee-dispatch"
ENV["OTEL_SERVICE_VERSION"] ||= "development"
ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] ||= "http://lgtm:4318"
ENV["OTEL_EXPORTER_OTLP_PROTOCOL"] ||= "http/protobuf"
ENV["OTEL_PROPAGATORS"] ||= "tracecontext,baggage"
ENV["OTEL_TRACES_SAMPLER"] ||= "parentbased_traceidratio"
ENV["OTEL_TRACES_SAMPLER_ARG"] ||= "0.1"
ENV["OTEL_LOG_LEVEL"] ||= "error"
if Rails.env.test?
  ENV["OTEL_TRACES_EXPORTER"] ||= "none"
  ENV["OTEL_METRICS_EXPORTER"] ||= "none"
  ENV["OTEL_LOGS_EXPORTER"] ||= "none"
end

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry-metrics-sdk"
require "opentelemetry/exporter/otlp_metrics"
require "opentelemetry-logs-sdk"
require "opentelemetry/exporter/otlp_logs"
require "opentelemetry/instrumentation/rack"
require "opentelemetry/instrumentation/action_pack"
require "opentelemetry/instrumentation/active_record"
require "opentelemetry/instrumentation/redis"
require "opentelemetry/instrumentation/faraday"
require "opentelemetry/instrumentation/aws_sdk"
require "opentelemetry/instrumentation/sidekiq"
require "opentelemetry/instrumentation/logger"

OpenTelemetry::SDK.configure do |config|
  metric_exporter = case ENV.fetch("OTEL_METRICS_EXPORTER", "otlp")
  when "otlp"
    OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new
  when "in-memory"
    OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
  end
  if metric_exporter
    config.add_metric_reader(
      OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader.new(
        exporter: metric_exporter,
        export_interval_millis: Integer(ENV.fetch("OTEL_METRIC_EXPORT_INTERVAL", "60000"))
      )
    )
  end

  config.use "OpenTelemetry::Instrumentation::Rack", { untraced_endpoints: ["/health"] }
  config.use "OpenTelemetry::Instrumentation::ActionPack"
  config.use "OpenTelemetry::Instrumentation::ActiveRecord"
  config.use "OpenTelemetry::Instrumentation::Redis", { db_statement: :obfuscate }
  config.use "OpenTelemetry::Instrumentation::Faraday", { enable_internal_instrumentation: false }
  config.use "OpenTelemetry::Instrumentation::AwsSdk", {
    inject_messaging_context: true,
    enable_internal_instrumentation: false
  }
  config.use "OpenTelemetry::Instrumentation::Sidekiq", { propagation_style: :child }
  config.use "OpenTelemetry::Instrumentation::Logger"
end
