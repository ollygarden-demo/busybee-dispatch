class OutboxDispatcherJob
  include Sidekiq::Job

  sidekiq_options queue: :outbox, retry: 5

  def perform
    OutboxEvent.pending.limit(100).pluck(:id).each { |id| dispatch(id) }
  end

  private

  def dispatch(id)
    event = OutboxEvent.find(id)
    event.with_lock do
      return if event.dispatched_at?

      dispatch_event(event)
      event.update!(dispatched_at: Time.current)
    end
  end

  def dispatch_event(event)
    case event.event_type
    when "assignment_requested"
      AssignmentJob.perform_async(event.aggregate_id)
    when "assignment_notification", "delivery_cancelled", "delivery_picked_up"
      NotificationJob.perform_async(event.id)
    when "delivery_completed"
      ProofOfDeliveryJob.perform_async(event.id) if event.payload["proof"].present?
      NotificationJob.perform_async(event.id)
    else
      Rails.logger.error("Unknown outbox event type")
      raise KeyError, event.event_type
    end
  end
end
