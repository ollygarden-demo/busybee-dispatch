class AssignmentService
  Result = Data.define(:outcome, :reason)

  def initialize(delivery, routing_client: RoutingClient.new, radius_m: DispatchSettings.max_radius_m)
    @delivery = delivery
    @routing_client = routing_client
    @radius_m = radius_m
  end

  def call
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    BusybeeDispatch::Telemetry.in_span("delivery.assignment", attributes: { "busybee.workflow" => "assignment" }) do |span|
      result = nil
      locked = @delivery.with_advisory_lock("delivery-assignment-#{@delivery.id}", timeout_seconds: 0) do
        result = assign
      end
      result = Result.new(outcome: :transient, reason: "lock_unavailable") unless locked
      span.set_attribute("busybee.assignment.outcome", result.outcome.to_s)
      BusybeeDispatch::Telemetry.record_assignment(
        result.outcome,
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      )
      result
    end
  end

  private

  def assign
    return Result.new(outcome: :ignored, reason: "not_pending") unless @delivery.reload.current_state == "pending"

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Delivery.transaction do
      DeliveryTransitioner.call(@delivery, :assigning)
      courier = nearest_courier
      if courier
        assign_courier(courier, started_at)
      else
        transient("no_available_courier", started_at)
      end
    rescue RoutingClient::TransientError => error
      transient(error.reason, started_at, courier)
    rescue RoutingClient::PermanentError => error
      permanent(error.message, started_at, courier)
    end
  end

  def assign_courier(courier, started_at)
    eta = @routing_client.eta_seconds(origin: @delivery.pickup, destination: @delivery.dropoff)
    courier.update!(availability: "reserved")
    DeliveryTransitioner.call(@delivery, :assigned, attributes: { courier_id: courier.id, eta_seconds: eta })
    record_attempt("assigned", nil, started_at, courier)
    OutboxEvent.create!(
      event_type: "assignment_notification",
      aggregate_id: @delivery.id,
      payload: { outcome: "assigned" }
    )
    Result.new(outcome: :assigned, reason: nil)
  end

  def nearest_courier
    Courier
      .joins("CROSS JOIN hubs dispatch_hub CROSS JOIN deliveries dispatch_delivery")
      .where(availability: "available")
      .where.not(location: nil)
      .where("dispatch_hub.id = ? AND dispatch_delivery.id = ?", @delivery.hub_id, @delivery.id)
      .where("ST_Covers(dispatch_hub.delivery_zone::geometry, couriers.location::geometry)")
      .where("ST_DWithin(couriers.location, dispatch_delivery.pickup, ?)", @radius_m)
      .order(Arel.sql("ST_Distance(couriers.location, dispatch_delivery.pickup), couriers.id"))
      .lock("FOR UPDATE OF couriers SKIP LOCKED")
      .first
  end

  def transient(reason, started_at, courier = nil)
    courier&.update!(availability: "available")
    DeliveryTransitioner.call(@delivery, :pending, metadata: { reason: reason })
    record_attempt("transient_failure", reason, started_at, courier)
    Result.new(outcome: :transient, reason: reason)
  end

  def permanent(reason, started_at, courier = nil)
    courier&.update!(availability: "available")
    DeliveryTransitioner.call(@delivery, :failed, metadata: { reason: reason })
    record_attempt("permanent_failure", reason, started_at, courier)
    Result.new(outcome: :permanent, reason: reason)
  end

  def record_attempt(outcome, reason, started_at, courier)
    @delivery.dispatch_attempts.create!(
      courier: courier,
      outcome: outcome,
      reason: reason,
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000).round
    )
  end
end
