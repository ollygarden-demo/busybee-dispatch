require "rails_helper"

RSpec.describe "API authentication", type: :request do
  around do |example|
    previous_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = "test-secret"
    example.run
  ensure
    ENV["JWT_SECRET"] = previous_secret
  end

  it "rejects a signed token without an expiration" do
    token = encode(sub: "operator", iss: "busybee-dispatch", aud: "busybee-api")

    get "/api/v1/deliveries/#{SecureRandom.uuid}", headers: authorization(token)

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts all required claims before loading the resource" do
    token = encode(sub: "operator", iss: "busybee-dispatch", aud: "busybee-api", exp: 1.hour.from_now.to_i)

    get "/api/v1/deliveries/#{SecureRandom.uuid}", headers: authorization(token)

    expect(response).to have_http_status(:not_found)
  end

  def encode(payload)
    JWT.encode(payload, ENV.fetch("JWT_SECRET"), "HS256")
  end

  def authorization(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
