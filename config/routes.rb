Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "registrations" }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # The homepage form posts here to save a floor / locker number (002 FR-001, FR-002).
  resource :locker_profile, only: :update

  # 003: the page listing everyone's active wishes (FR-011), and declaring one
  # (FR-001). Singular for the write: a user only ever acts on their own single
  # wish, so there is no :id to put in the path.
  resources :locker_wishes, only: :index
  resource :locker_wish, only: [ :create, :destroy ]

  # Defines the root path route ("/") — the homepage a successful login lands on (FR-005).
  root "home#index"
end
