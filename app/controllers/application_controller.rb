class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render_error(:not_found, "resource not found", :not_found)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error(:validation_failed, error.record.errors.full_messages.to_sentence, :unprocessable_entity)
  end


  rescue_from ActionController::ParameterMissing do |error|
    render_error(:validation_failed, error.message, :unprocessable_entity, path: error.param)
  end

  rescue_from DeliveryTransitioner::InvalidTransition do
    render_error(:invalid_transition, "delivery cannot make that transition", :conflict)
  end

  rescue_from ArgumentError do |error|
    render_error(:invalid_coordinates, error.message, :unprocessable_entity)
  end

  private

  def render_error(code, message, status, path: nil)
    error = { code: code.to_s, message: message }
    error[:path] = path if path
    render json: { errors: [error] }, status: status
  end
end
