Shoryuken.configure_server do |config|
  config.sqs_client = AwsClients.sqs
end

Shoryuken.configure_client { |config| config.sqs_client = AwsClients.sqs }
