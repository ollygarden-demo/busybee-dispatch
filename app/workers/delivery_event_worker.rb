class DeliveryEventWorker
  include Shoryuken::Worker

  shoryuken_options queue: ENV.fetch("SQS_QUEUE_URL", "busybee-deliveries"),
                    auto_delete: true,
                    auto_visibility_timeout: true,
                    body_parser: :text

  def perform(_sqs_message, body)
    result = DeliveryEventProcessor.call(body)
    Rails.logger.info("Delivery event processing finished with #{result}")
  end
end
