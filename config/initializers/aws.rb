module AwsClients
  class << self
    def dynamodb
      @dynamodb ||= Aws::DynamoDB::Client.new(client_options)
    end

    def s3
      @s3 ||= Aws::S3::Client.new(client_options.merge(force_path_style: localstack?))
    end

    def sns
      @sns ||= Aws::SNS::Client.new(client_options)
    end

    def sqs
      @sqs ||= Aws::SQS::Client.new(client_options)
    end

    def ssm
      @ssm ||= Aws::SSM::Client.new(client_options)
    end

    private

    def client_options
      options = { region: ENV.fetch("AWS_REGION", "eu-central-1") }
      return options.merge(stub_responses: true) if Rails.env.test?
      return options unless localstack?

      options.merge(
        endpoint: endpoint,
        credentials: Aws::Credentials.new("local", "local"),
        http_open_timeout: 1,
        http_read_timeout: 2,
        retry_limit: 1
      )
    end

    def localstack?
      endpoint.present?
    end

    def endpoint
      ENV["LOCALSTACK_ENDPOINT"] || ENV["AWS_ENDPOINT_URL"]
    end
  end
end
