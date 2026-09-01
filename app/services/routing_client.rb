class RoutingClient
  class TransientError < StandardError
    attr_reader :reason

    def initialize(reason, message = reason)
      @reason = reason
      super(message)
    end
  end
  class PermanentError < StandardError; end

  def initialize(connection: nil)
    @connection = connection || Faraday.new(url: ENV.fetch("ROUTING_URL", "http://routing:8080")) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.options.open_timeout = 1
      faraday.options.timeout = 3
      faraday.adapter :typhoeus
    end
  end

  def eta_seconds(origin:, destination:)
    response = Circuitbox.circuit(
      :routing,
      exceptions: [Faraday::Error, TransientError],
      volume_threshold: 5,
      time_window: 60,
      sleep_window: 30
    ).run do
      response = @connection.post("/route", origin: coordinates(origin), destination: coordinates(destination))
      raise TransientError.new("routing_5xx", "routing service returned #{response.status}") if response.status >= 500

      response
    end

    raise PermanentError, "routing service returned #{response.status}" unless response.success?

    eta = response.body["eta_seconds"]
    raise PermanentError, "routing response did not contain a valid ETA" unless eta.is_a?(Integer) && eta.positive?

    eta
  rescue Circuitbox::OpenCircuitError => error
    raise TransientError.new("circuit_open", error.message)
  rescue Faraday::TimeoutError => error
    raise TransientError.new("routing_timeout", error.message)
  rescue Faraday::ConnectionFailed => error
    raise TransientError.new("routing_unavailable", error.message)
  end

  private

  def coordinates(point)
    [point.x, point.y]
  end
end
