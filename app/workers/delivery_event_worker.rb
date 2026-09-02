class DeliveryEventWorker
  include Shoryuken::Worker

  shoryuken_options queue: ENV.fetch("SQS_QUEUE_URL", "busybee-deliveries"),
                    auto_delete: true,
                    auto_visibility_timeout: true,
                    body_parser: :text

  def perform(sqs_message, body)
    carrier = BusybeeDispatch::Telemetry.sqs_carrier(sqs_message)
    BusybeeDispatch::Telemetry.with_extracted_context(carrier) do
      BusybeeDispatch::Telemetry.in_span(
        "busybee-deliveries receive",
        attributes: {
          "messaging.system" => "aws.sqs",
          "messaging.operation.type" => "receive",
          "messaging.destination.name" => "busybee-deliveries"
        },
        kind: :consumer
      ) do
        result = DeliveryEventProcessor.call(body)
        Rails.logger.info("Delivery event processing finished with #{result}")
      end
    end
  end
end
