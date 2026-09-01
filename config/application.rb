require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "digest"
require "time"

Bundler.require(*Rails.groups)

module BusybeeDispatch
  class Application < Rails::Application
    config.load_defaults 7.2
    config.api_only = true
    config.active_record.dump_schema_after_migration = false

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins ENV.fetch("CORS_ORIGINS", "http://localhost:3000").split(",")
        resource "/api/*", headers: :any, methods: %i[get post put options]
      end
    end
  end
end
