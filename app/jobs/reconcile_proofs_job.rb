class ReconcileProofsJob
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 3, lock: :until_executed

  def perform
    OutboxEvent
      .where(event_type: "delivery_completed")
      .where.not(dispatched_at: nil)
      .where("payload ? 'proof'")
      .joins("INNER JOIN deliveries ON deliveries.id = outbox_events.aggregate_id")
      .where(deliveries: { proof_stored_at: nil })
      .update_all(dispatched_at: nil, updated_at: Time.current)
  end
end
