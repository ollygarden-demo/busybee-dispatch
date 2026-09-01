class DeliveryTransitioner
  class InvalidTransition < StandardError; end

  def self.call(delivery, state, metadata: {}, attributes: {}, event_type: nil, payload: {})
    Delivery.transaction do
      delivery.lock!
      raise InvalidTransition unless delivery.state_machine.can_transition_to?(state)

      courier = delivery.courier
      if courier
        courier.update!(availability: "carrying") if state == :picked_up
        courier.update!(availability: "available") if %i[pending delivered cancelled failed].include?(state)
        attributes = attributes.merge(courier_id: nil) if %i[pending cancelled failed].include?(state)
      end
      delivery.update!(attributes) if attributes.any?
      delivery.state_machine.transition_to!(state, metadata)
      OutboxEvent.create!(
        event_type: event_type,
        aggregate_id: delivery.id,
        payload: payload.merge(delivery_id: delivery.id)
      ) if event_type
      delivery
    end
  rescue Statesman::GuardFailedError, Statesman::TransitionFailedError
    raise InvalidTransition
  end
end
