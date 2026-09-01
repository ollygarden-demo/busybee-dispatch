class DeliveryTransition < ApplicationRecord
  belongs_to :delivery, inverse_of: :delivery_transitions
end
