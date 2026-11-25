source "https://rubygems.org"

ruby ">= 3.2.0"

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

group :test do
  gem "opentelemetry-exporter-otlp", "~> 0.37.0", require: false
  gem "opentelemetry-sdk", "~> 1.13", require: false
end
