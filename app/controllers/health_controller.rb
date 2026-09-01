class HealthController < ApplicationController
  def show
    checks = { application: "ok", postgresql: postgresql_status, redis: redis_status }
    status = checks.values.all?("ok") ? :ok : :service_unavailable
    render json: { status: status == :ok ? "ok" : "unavailable", checks: checks }, status: status
  end

  private

  def postgresql_status
    ActiveRecord::Base.connection.select_value("SELECT 1") == 1 ? "ok" : "unavailable"
  rescue StandardError
    "unavailable"
  end

  def redis_status
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping == "PONG" ? "ok" : "unavailable"
  rescue Redis::BaseError
    "unavailable"
  end
end
