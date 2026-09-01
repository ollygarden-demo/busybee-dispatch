class DeliverySerializer
  def self.call(delivery)
    {
      data: {
        id: delivery.id,
        external_id: delivery.external_id,
        hub_id: delivery.hub_id,
        courier_id: delivery.courier_id,
        state: delivery.current_state,
        pickup: point(delivery.pickup),
        dropoff: point(delivery.dropoff),
        eta_seconds: delivery.eta_seconds,
        created_at: delivery.created_at.iso8601,
        updated_at: delivery.updated_at.iso8601,
        transitions: delivery.delivery_transitions.map do |transition|
          {
            state: transition.to_state,
            metadata: transition.metadata,
            created_at: transition.created_at.iso8601
          }
        end
      }
    }
  end

  def self.point(value)
    { type: "Point", coordinates: Geo.coordinates(value) }
  end

  private_class_method :point
end
