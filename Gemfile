source "https://rubygems.org"

ruby ">= 3.3.0"

# OpenTelemetry tracing is stable; metrics and logs are intentionally pinned to
# their independently released experimental SDKs.
gem "opentelemetry-sdk", "~> 1.13"
gem "opentelemetry-exporter-otlp", "~> 0.35"
gem "opentelemetry-instrumentation-rack", "~> 0.31"
gem "opentelemetry-instrumentation-action_pack", "~> 0.18"
gem "opentelemetry-instrumentation-active_record", "~> 0.13"
gem "opentelemetry-instrumentation-redis", "~> 0.29"
gem "opentelemetry-instrumentation-faraday", "~> 0.33"
gem "opentelemetry-instrumentation-aws_sdk", "~> 0.13"
gem "opentelemetry-instrumentation-sidekiq", "~> 0.29"
gem "opentelemetry-instrumentation-logger", "~> 0.4"
gem "opentelemetry-metrics-api", "~> 0.7"
gem "opentelemetry-metrics-sdk", "~> 0.17"
gem "opentelemetry-exporter-otlp-metrics", "~> 0.11"
gem "opentelemetry-logs-api", "~> 0.4"
gem "opentelemetry-logs-sdk", "~> 0.6"
gem "opentelemetry-exporter-otlp-logs", "~> 0.5"

gem "rails", "~> 7.2.3"
gem "bootsnap", require: false
gem "puma", "~> 7.1"
gem "rack-cors"

gem "activerecord-postgis-adapter", "~> 10.0"
gem "aws-sdk-dynamodb"
gem "aws-sdk-s3"
gem "aws-sdk-sns"
gem "aws-sdk-sqs"
gem "aws-sdk-ssm"
gem "circuitbox"
gem "faraday", "~> 2.14"
gem "faraday-typhoeus"
gem "jwt"
gem "json-schema"
gem "moneta"
gem "pg", "~> 1.6.2"
gem "redis"
gem "shoryuken", "~> 6.2.1"
gem "sidekiq"
gem "sidekiq-cron"
gem "sidekiq-unique-jobs"
gem "statesman", "13.1.0"
gem "with_advisory_lock"

group :development, :test do
  gem "dotenv-rails"
  gem "rspec-rails", "~> 8.0"
end
