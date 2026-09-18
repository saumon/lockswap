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

  # 004: proposing a swap (:create), withdrawing one still pending (:destroy),
  # and the read-only history screen (:index). The three decisions are member
  # actions rather than a status param, so each one's own authorization and
  # state rules stay separate (FR-001, FR-005, FR-012, FR-015, FR-019).
  resources :locker_swap_proposals, only: [ :create, :destroy, :index ] do
    member do
      patch :accept
      patch :decline
      patch :confirm
    end
  end

  # 013 FR-005: the administrator's own corner of the site. Namespaced from the
  # start, though it holds one destination today: "Admin" is a menu in the
  # navigation, and what sits under it belongs under it in the routes too.
  #
  # 015: the screen gained one write. A named member action rather than :update
  # with a parameter, for the reason locker_swap_proposals routes accept/decline/
  # confirm the same way — each decision keeps its own authorization and rules —
  # and because a general update action on accounts is precisely what 015 FR-014
  # says must not exist. A named action cannot be widened by accident.
  namespace :admin do
    resources :users, only: :index do
      member do
        patch :grant_admin
      end
    end
  end

  # Defines the root path route ("/") — the homepage a successful login lands on (FR-005).
  root "home#index"
end
