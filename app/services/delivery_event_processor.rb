class DeliveryEventProcessor
  class InvalidEvent < StandardError; end

  SCHEMA_PATH = Rails.root.join("config/schemas/delivery_created.json")

  def self.call(body)
    BusybeeDispatch::Telemetry.in_span(
      "delivery.event.process",
      attributes: {
        "busybee.workflow" => "delivery_event",
        "messaging.system" => "aws.sqs",
        "messaging.operation.type" => "process",
        "messaging.destination.name" => "busybee-deliveries"
      },
      kind: :internal
    ) do |span|
      begin
        event = begin
          JSON.parse(body)
        rescue JSON::ParserError => error
          raise InvalidEvent, error.message
        end
        errors = JSON::Validator.fully_validate(SCHEMA_PATH.to_s, event, validate_format: true)
        raise InvalidEvent, errors.join(", ") if errors.any?

        token = EventLease.acquire(event.fetch("event_id"))
        result = if token == EventLease::COMPLETED
          :duplicate
        else
          begin
            create_delivery(event)
            EventLease.complete(event.fetch("event_id"), token)
            :created
          rescue StandardError
            EventLease.release(event.fetch("event_id"), token)
            raise
          end
        end
        span.set_attribute("busybee.event.result", result.to_s)
        BusybeeDispatch::Telemetry.record_event(result)
        result
      rescue InvalidEvent
        BusybeeDispatch::Telemetry.record_event(:rejected)
        raise
      rescue StandardError
        BusybeeDispatch::Telemetry.record_event(:failed)
        raise
      end
    end
  end

  def self.create_delivery(event)
    DeliveryCreator.call(
      external_id: event.fetch("external_id"),
      hub_id: event.fetch("hub_id"),
      pickup: Geo.point(event.dig("pickup", "coordinates")),
      dropoff: Geo.point(event.dig("dropoff", "coordinates")),
      recipient_name: event.dig("recipient", "name"),
      recipient_phone: event.dig("recipient", "phone")
    )
  rescue ActiveRecord::RecordNotUnique
    Delivery.find_by!(external_id: event.fetch("external_id"))
  end
  private_class_method :create_delivery
end
