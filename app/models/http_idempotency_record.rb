class HttpIdempotencyRecord < ApplicationRecord
  validates :subject, :key, :request_hash, :expires_at, presence: true
  validates :key, uniqueness: { scope: :subject }
end
