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
  #
  # 026: :new carries no form of its own — a singular resource has nowhere else
  # to put it. It exists so the homepage's two invitations can hand the wish
  # page an intention to open its declare form without that intention ever
  # appearing in the address (FR-001/FR-003); the action sets a flash entry and
  # redirects straight to locker_wishes_path. The class's own
  # before_action :authenticate_user! already covers it, since a singular
  # `resource` still routes to the plural LockerWishesController.
  resources :locker_wishes, only: :index
  resource :locker_wish, only: [ :new, :create, :destroy ]

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
    # 027 FR-001/FR-002: the detail screen for one account, admin-only like the
    # list it is reached from. Two writes made on that account's behalf are
    # nested singular resources rather than folded into #update, the same
    # reasoning #grant_admin already follows — each keeps its own authorization
    # and rules, and a general update on accounts is exactly what 015 FR-014
    # forbids.
    resources :users, only: [ :index, :show ] do
      member do
        patch :grant_admin
        patch :revoke_admin
      end

      resource :locker_profile, only: :update, controller: "user_locker_profiles"
      resource :locker_wish, only: :destroy, controller: "user_locker_wishes"
    end

    # 016 FR-001: the Danger Zone screen. Singular — a screen that shows (and, as
    # of 025, edits one setting of its own) rather than a resource anybody lists.
    # What the allowed-domains section manages has its own identity and its own
    # validations, so it is routed separately below rather than as writes hung
    # off this one (research.md R3). 025 FR-011: the language setting IS this
    # screen's own state, unlike the domains, so it gets #update here directly
    # rather than a sibling controller (research.md R6).
    #
    # controller: names it explicitly because a singular `resource` otherwise
    # routes to a pluralized controller ("DangerZonesController"), and there is
    # only ever one danger zone.
    resource :danger_zone, only: [ :show, :update ], controller: "danger_zone"

    # 030 FR-001: the floor list shown on the Danger Zone. A singleton of its own
    # — one list, edited in place — with its own validations, so it is routed
    # beside the screen rather than folded into DangerZoneController#update,
    # which is the language setting's write (research.md R7). controller: for the
    # same pluralization reason as above.
    resource :floor_list, only: :update, controller: "floor_list"

    # 030 FR-009: the locker number format, routed the same way for the same
    # reasons as the floor list above.
    resource :locker_number_format, only: :update, controller: "locker_number_format"

    # 016 FR-003: the domains themselves. No :update — changing a domain is
    # remove-then-add, which leaves the resource with exactly the two operations
    # the spec describes and no partially-edited state to validate.
    resources :allowed_email_domains, only: [ :create, :destroy ]

    # 031 FR-001/FR-002: the Locker Map screen. Singular — one screen, like the
    # danger zone — and controller: for the same pluralization reason as
    # :locker_number_format above (a bare `resource :locker_map` would route
    # to "LockerMapsController"). Ordinary admin-only (require_admin!), not the
    # super-admin-only guard the danger zone and its own resources above use
    # (research.md R7).
    resource :locker_map, only: :show, controller: "locker_map"

    # 031 FR-003 through FR-008: zones and, nested under one, the locker
    # numbers it declares. Nested because a locker map entry only ever makes
    # sense within its zone — there is no reason to address one independently
    # (mirrors admin/locker_profile's nesting under admin/users).
    resources :zones, only: [ :create, :update, :destroy ] do
      resources :locker_map_entries, only: [ :create, :destroy ]
    end
  end

  # Defines the root path route ("/") — the homepage a successful login lands on (FR-005).
  root "home#index"
end
