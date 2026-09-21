require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Lockswap
  class Application < Rails::Application
    # 007 FR-003: how long a flash notification stays on screen before it takes
    # itself away. This is the figure that ships; config/environments/test.rb
    # shortens the countdown so the suite is not spending real seconds waiting
    # one out, and test/views/layouts/flash_test.rb holds this value to the spec.
    NOTIFICATION_AUTO_DISMISS_MS = 3000

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    config.x.notification_auto_dismiss_ms = NOTIFICATION_AUTO_DISMISS_MS

    # 025 FR-003/FR-005: the two languages the Danger Zone setting may hold, and
    # the installation default before an administrator ever configures one.
    # config.i18n.fallbacks is what makes FR-010's "no translation? show English"
    # requirement true without a rescue anywhere — see research.md R4/R9 for what
    # it does and does not cover.
    config.i18n.available_locales = [ :en, :fr ]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = true

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
