module Api
  module V1
    class ApplicationController < ::ApplicationController
      before_action :authenticate!
      around_action :enforce_idempotency, if: -> { request.post? || request.put? || request.patch? }

      private

      attr_reader :authenticated_subject

      def authenticate!
        secret = ENV["JWT_SECRET"]
        token = request.authorization&.delete_prefix("Bearer ")
        raise JWT::DecodeError if secret.blank? || token.blank?

        payload, = JWT.decode(
          token,
          secret,
          true,
          algorithm: "HS256",
          iss: "busybee-dispatch",
          verify_iss: true,
          aud: "busybee-api",
          verify_aud: true,
          required_claims: %w[exp iss aud sub]
        )
        @authenticated_subject = payload.fetch("sub")
      rescue JWT::DecodeError, JWT::ExpiredSignature, KeyError
        render_error(:unauthorized, "a valid bearer token is required", :unauthorized)
      end

      def enforce_idempotency
        key = request.headers["Idempotency-Key"]
        return render_error(:validation_failed, "Idempotency-Key is required", :unprocessable_entity, path: "Idempotency-Key") if key.blank?

        request_hash = Digest::SHA256.hexdigest([request.method, request.path, canonical_json(request.raw_post)].join("\n"))
        HttpIdempotencyRecord.transaction do
          record = HttpIdempotencyRecord.lock.find_by(subject: authenticated_subject, key: key)
          if record && record.expires_at > Time.current
            if record.request_hash != request_hash
              render_error(:idempotency_conflict, "key was already used for another request", :conflict)
            elsif record.response_status
              render json: record.response_body, status: record.response_status
            else
              render_error(:concurrent_update, "a request with this key is still processing", :conflict)
            end
            next
          end

          attributes = { request_hash: request_hash, response_status: nil, response_body: nil, expires_at: 24.hours.from_now }
          if record
            record.update!(attributes)
          else
            record = HttpIdempotencyRecord.create!(attributes.merge(subject: authenticated_subject, key: key))
          end

          yield
          record.update!(response_status: response.status, response_body: JSON.parse(response.body))
        end
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      def canonical_json(raw_body)
        canonicalize(raw_body.present? ? JSON.parse(raw_body) : {}).to_json
      rescue JSON::ParserError
        raw_body
      end

      def canonicalize(value)
        case value
        when Hash then value.keys.sort.to_h { |key| [key, canonicalize(value[key])] }
        when Array then value.map { |item| canonicalize(item) }
        else value
        end
      end
    end
  end
end
