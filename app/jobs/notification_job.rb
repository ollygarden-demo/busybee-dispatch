class NotificationJob
  include Sidekiq::Job

  sidekiq_options queue: :notifications, retry: 5

  def perform(outbox_event_id)
    event = OutboxEvent.find(outbox_event_id)
    AwsClients.sns.publish(
      topic_arn: ENV.fetch("DISPATCH_TOPIC_ARN"),
      message: JSON.generate(
        event_id: event.id,
        event_type: event.event_type,
        delivery_id: event.aggregate_id,
        outcome: event.payload["outcome"]
      )
    )
  end
end
