module Api
  module V1
    class HubsController < ApplicationController
      MAX_PER_PAGE = 100

      def nearby_couriers
        hub = Hub.find(params[:id])
        page = [params.fetch(:page, 1).to_i, 1].max
        per_page = params.fetch(:per_page, 20).to_i.clamp(1, MAX_PER_PAGE)
        radius = params.fetch(:radius_m, 5_000).to_f.clamp(1, 5_000)

        candidates = Courier.where(availability: "available").where.not(location: nil)
          .where("ST_Covers(?, couriers.location)", hub.delivery_zone)
          .where("ST_DWithin(couriers.location, ?, ?)", hub.location, radius)
        total = candidates.count
        rows = candidates
          .select("couriers.*, ST_Distance(couriers.location, #{quoted_point(hub.location)}) AS distance_m")
          .order(Arel.sql("distance_m ASC, couriers.id ASC"))
          .offset((page - 1) * per_page)
          .limit(per_page)

        render json: {
          data: rows.map { |courier| { id: courier.id, availability: courier.availability, distance_m: courier.distance_m.to_f.round(1) } },
          meta: { page: page, per_page: per_page, total: total }
        }
      end

      private

      def quoted_point(point)
        ActiveRecord::Base.connection.quote(point)
      end
    end
  end
end
