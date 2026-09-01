Rails.application.routes.draw do
  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      resources :deliveries, only: %i[create show] do
        member do
          post :pick_up
          post :deliver
          post :cancel
        end
      end
      resources :couriers, only: [] do
        member { put :location }
      end
      resources :hubs, only: [] do
        member { get :nearby_couriers }
      end
    end
  end
end
