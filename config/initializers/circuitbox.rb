Circuitbox.configure do |config|
  config.default_circuit_store = Moneta.new(:Redis, url: ENV.fetch("CIRCUIT_REDIS_URL", "redis://redis:6379/2"))
end
