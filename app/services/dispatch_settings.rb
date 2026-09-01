class DispatchSettings
  DEFAULT_RADIUS_M = 5_000

  def self.max_radius_m
    value = AwsClients.ssm.get_parameter(name: "/busybee/dispatch/max_radius_m").parameter.value
    Integer(value)
  rescue Aws::SSM::Errors::ServiceError, Seahorse::Client::NetworkingError, ArgumentError
    Rails.logger.warn("Using default dispatch radius")
    DEFAULT_RADIUS_M
  end
end
