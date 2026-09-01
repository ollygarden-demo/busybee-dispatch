module Api
  module V1
    class DeliveriesController < ApplicationController
      before_action :load_delivery, except: :create

      def create
        delivery = DeliveryCreator.call(
          external_id: params.require(:external_id),
          hub_id: params.require(:hub_id),
          pickup: coordinates(:pickup),
          dropoff: coordinates(:dropoff),
          recipient_name: params.require(:recipient).fetch(:name),
          recipient_phone: params.require(:recipient).fetch(:phone)
        )
        Rails.logger.info("Delivery accepted for assignment")
        render json: DeliverySerializer.call(delivery), status: :accepted
      end

      def show
        render json: DeliverySerializer.call(@delivery)
      end

      def pick_up
        occurred_at = timestamp(:occurred_at)
        delivery = DeliveryTransitioner.call(
          @delivery,
          :picked_up,
          attributes: { picked_up_at: occurred_at },
          event_type: "delivery_picked_up"
        )
        render json: DeliverySerializer.call(delivery)
      end

      def deliver
        occurred_at = timestamp(:occurred_at)
        proof = params[:proof]&.permit(:type, :note)&.to_h
        delivery = DeliveryTransitioner.call(
          @delivery,
          :delivered,
          attributes: { delivered_at: occurred_at },
          event_type: "delivery_completed",
          payload: proof.present? ? { proof: proof } : {}
        )
        render json: DeliverySerializer.call(delivery)
      end

      def cancel
        reason = params.require(:reason)
        unless %w[recipient_request courier_unavailable operator_request].include?(reason)
          return render_error(:validation_failed, "reason is not supported", :unprocessable_entity, path: "reason")
        end

        occurred_at = timestamp(:occurred_at)
        retry_assignment = reason == "courier_unavailable" && @delivery.current_state == "assigned"
        delivery = if retry_assignment
          DeliveryTransitioner.call(
            @delivery,
            :pending,
            metadata: { reason: reason, occurred_at: occurred_at },
            event_type: "assignment_requested"
          )
        else
          DeliveryTransitioner.call(
            @delivery,
            :cancelled,
            metadata: { reason: reason },
            attributes: { cancelled_at: occurred_at },
            event_type: "delivery_cancelled",
            payload: { reason: reason }
          )
        end
        render json: DeliverySerializer.call(delivery)
      end

      private

      def load_delivery
        @delivery = Delivery.includes(:delivery_transitions).find(params[:id])
      end

      def coordinates(key)
        value = params.require(key).require(:coordinates)
        raise ArgumentError, "#{key}.coordinates must contain longitude and latitude" unless value.is_a?(Array) && value.length == 2

        Geo.point(value)
      end

      def timestamp(key)
        value = Time.iso8601(params.require(key))
        raise ArgumentError, "#{key} must be in UTC" unless value.utc_offset.zero?

        value
      rescue ArgumentError
        raise ArgumentError, "#{key} must be an ISO 8601 UTC timestamp"
      end
    end
  end
end
