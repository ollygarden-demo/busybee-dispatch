class ExpireStaleDeliveriesJob
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 3

  def perform
    stale_pending.find_each do |delivery|
      DeliveryTransitioner.call(
        delivery,
        :cancelled,
        metadata: { reason: "assignment_timeout" },
        attributes: { cancelled_at: Time.current },
        event_type: "delivery_cancelled",
        payload: { reason: "assignment_timeout" }
      )
    rescue DeliveryTransitioner::InvalidTransition
      next
    end
  end

  private

  def stale_pending
    Delivery
      .joins("LEFT JOIN delivery_transitions current_transition ON current_transition.delivery_id = deliveries.id AND current_transition.most_recent")
      .where("deliveries.created_at < ?", 30.minutes.ago)
      .where("current_transition.to_state IS NULL OR current_transition.to_state = 'pending'")
  end
end
