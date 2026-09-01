Rails.application.config.filter_parameters += %i[
  authorization
  coordinates
  dropoff
  jwt
  password
  phone
  pickup
  proof
  recipient
  secret
  token
]
