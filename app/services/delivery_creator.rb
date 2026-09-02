class DeliveryCreator
  def self.call(attributes)
    BusybeeDispatch::Telemetry.in_span("delivery.create", attributes: { "busybee.workflow" => "delivery_create" }) do |span|
      Delivery.transaction do
        delivery = Delivery.create!(attributes)
        OutboxEvent.create!(
          event_type: "assignment_requested",
          aggregate_id: delivery.id,
          payload: { delivery_id: delivery.id }
        )
        span.set_attribute("busybee.delivery.created", true)
        delivery
      end
    end
  end
end
