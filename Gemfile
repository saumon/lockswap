source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Accessibility assertions for the system suite (008 FR-028). The gem bundles
  # its own axe.min.js, so there is no npm step and nothing to pin in the
  # importmap. Deliberately not axe-core-capybara: that gem's configure step
  # reassigns Capybara.default_driver and would discard the headless Chrome
  # driver and screen size set in test/application_system_test_case.rb.
  # require: false because the gem ships no axe-core-api.rb — its entry points are
  # "axe/api" and "axe/core", which test/application_system_test_case.rb requires
  # directly. Without this, Bundler's auto-require fails at boot.
  gem "axe-core-api", require: false
end

gem "devise", "~> 5.0"

# 025: French translations for Devise's own strings (failures, confirmations,
# mailer subjects) and for Rails/ActiveModel's own bundled messages (validation
# defaults, "N errors prohibited this record from being saved"). See
# research.md R5/R8 for why both are needed and why rails-i18n's date/time/number
# sections are pinned back to English in config/locales/fr.yml.
gem "devise-i18n"
gem "rails-i18n"

# json 3.0 made JSON.parse's options keyword-only, but Active Support 8.1.3.1 still
# passes them positionally (active_support/json/decoding.rb), which breaks every
# encrypted cookie read. Stay on the 2.x line until Rails ships the fix.
gem "json", "< 3"
