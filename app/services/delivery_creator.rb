class DeliveryCreator
  def self.call(attributes)
    Delivery.transaction do
      delivery = Delivery.create!(attributes)
      OutboxEvent.create!(
        event_type: "assignment_requested",
        aggregate_id: delivery.id,
        payload: { delivery_id: delivery.id }
      )
      delivery
    end
  end
end
