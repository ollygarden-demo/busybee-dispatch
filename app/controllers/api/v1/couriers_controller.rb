module Api
  module V1
    class CouriersController < ApplicationController
      def location
        courier = Courier.find(params[:id])
        availability = params.require(:availability)
        unless Courier::AVAILABILITIES.include?(availability)
          return render_error(:validation_failed, "availability is not supported", :unprocessable_entity, path: "availability")
        end

        observed_at = parse_observed_at
        coordinates = params.require(:coordinates)
        raise ArgumentError, "coordinates must contain longitude and latitude" unless coordinates.is_a?(Array) && coordinates.length == 2

        updated = courier.update_location(
          coordinates: coordinates,
          availability: availability,
          observed_at: observed_at
        )
        render json: { data: representation(courier), meta: { updated: updated } }
      end

      private

      def parse_observed_at
        value = Time.iso8601(params.require(:observed_at))
        raise ArgumentError unless value.utc_offset.zero?

        value
      rescue ArgumentError
        raise ArgumentError, "observed_at must be an ISO 8601 UTC timestamp"
      end

      def representation(courier)
        {
          id: courier.id,
          availability: courier.availability,
          observed_at: courier.location_observed_at&.iso8601
        }
      end
    end
  end
end
