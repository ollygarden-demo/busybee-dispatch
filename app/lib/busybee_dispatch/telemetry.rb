module BusybeeDispatch
  module Telemetry
    TRACER_NAME = "busybee-dispatch"
    METER_NAME = "busybee-dispatch"

    class << self
      def tracer
        OpenTelemetry.tracer_provider.tracer(TRACER_NAME, "1.0.0")
      end

      def meter
        OpenTelemetry.meter_provider.meter(METER_NAME, version: "1.0.0")
      end

      def in_span(name, attributes: {}, kind: :internal, &block)
        tracer.in_span(name, attributes: attributes, kind: kind, &block)
      end

      def with_extracted_context(carrier, &block)
        context = OpenTelemetry.propagation.extract(carrier)
        OpenTelemetry::Context.with_current(context, &block)
      end

      def sqs_carrier(message)
        attributes = message.respond_to?(:message_attributes) ? message.message_attributes : {}
        attributes.each_with_object({}) do |(key, value), carrier|
          carrier[key] = if value.respond_to?(:string_value)
            value.string_value
          else
            value.to_s
          end
        end
      end

      def record_assignment(outcome, duration_seconds)
        assignment_attempts.add(1, attributes: { "busybee.assignment.outcome" => outcome.to_s })
        assignment_duration.record(duration_seconds, attributes: { "busybee.assignment.outcome" => outcome.to_s })
      end

      def record_event(result)
        event_processing.add(1, attributes: { "busybee.event.result" => result.to_s })
      end

      private

      def assignment_attempts
        @assignment_attempts ||= meter.create_counter(
          "busybee.assignment.attempts",
          unit: "{attempt}",
          description: "Delivery assignment outcomes"
        )
      end

      def assignment_duration
        @assignment_duration ||= meter.create_histogram(
          "busybee.assignment.duration",
          unit: "s",
          description: "Time spent attempting delivery assignment"
        )
      end

      def event_processing
        @event_processing ||= meter.create_counter(
          "busybee.delivery.events",
          unit: "{event}",
          description: "Inbound delivery event processing outcomes"
        )
      end
    end
  end
end
