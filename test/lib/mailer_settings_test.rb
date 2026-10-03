require "test_helper"

# 034 FR-029, contracts/mail-configuration.md: every mail setting resolves
# ENV → encrypted credentials → default.
#
# Minitest 6 has no stub, so the two inputs are swapped by hand and always put
# back: ENV through with_env, the credentials lookup through with_credentials.
class MailerSettingsTest < ActiveSupport::TestCase
  Settings = Lockswap::MailerSettings

  SMTP_ENV = %w[SMTP_ENABLED SMTP_ADDRESS SMTP_PORT SMTP_DOMAIN SMTP_USERNAME SMTP_PASSWORD SMTP_AUTHENTICATION
                SMTP_ENABLE_STARTTLS_AUTO SMTP_OPENSSL_VERIFY_MODE SMTP_SENDER MAILER_SENDER
                APP_HOST APP_PORT APP_PROTOCOL].freeze

  # Runs with every mail variable cleared, then the given ones set.
  def with_env(values = {})
    saved = SMTP_ENV.index_with { |key| ENV[key] }
    SMTP_ENV.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  # Runs with the credentials reading as the given nested hash.
  def with_credentials(values = {})
    original = Settings.method(:credential)
    Settings.define_singleton_method(:credential) { |namespace, key| values.dig(namespace, key) }
    yield
  ensure
    Settings.define_singleton_method(:credential, original)
  end

  test "the environment wins over the credentials" do
    with_env("SMTP_ADDRESS" => "env.example") do
      with_credentials(smtp: { address: "cred.example" }) do
        assert_equal "env.example", Settings.smtp_settings[:address]
      end
    end
  end

  test "the credentials are used when the environment is unset or empty" do
    with_credentials(smtp: { address: "cred.example" }) do
      with_env { assert_equal "cred.example", Settings.smtp_settings[:address] }
      with_env("SMTP_ADDRESS" => "") { assert_equal "cred.example", Settings.smtp_settings[:address] }
    end
  end

  test "the defaults apply when neither is set" do
    with_env do
      with_credentials do
        assert_equal :plain, Settings.smtp_settings[:authentication]
        assert_equal true, Settings.smtp_settings[:enable_starttls_auto]
        assert_equal "fallback@example.com", Settings.mailer_sender(default: "fallback@example.com")
      end
    end
  end

  test "values are cast to the type SMTP expects" do
    with_env("SMTP_PORT" => "587", "SMTP_ENABLE_STARTTLS_AUTO" => "false", "SMTP_AUTHENTICATION" => "login") do
      with_credentials do
        assert_equal 587, Settings.smtp_settings[:port]
        assert_equal false, Settings.smtp_settings[:enable_starttls_auto]
        assert_equal :login, Settings.smtp_settings[:authentication]
      end
    end
  end

  # SMTP is only switched on with all four of address, port, user and password.
  test "SMTP counts as configured only when all four required settings are present" do
    complete = { "SMTP_ADDRESS" => "smtp.example", "SMTP_PORT" => "587",
                 "SMTP_USERNAME" => "user", "SMTP_PASSWORD" => "secret" }

    with_credentials do
      with_env(complete) { assert_predicate Settings, :smtp_configured? }
      with_env(complete.except("SMTP_PASSWORD")) { assert_not_predicate Settings, :smtp_configured? }
    end
  end

  test "the sender prefers SMTP_SENDER over MAILER_SENDER" do
    with_credentials do
      with_env("SMTP_SENDER" => "a@example.com", "MAILER_SENDER" => "b@example.com") do
        assert_equal "a@example.com", Settings.mailer_sender(default: "c@example.com")
      end
      with_env("MAILER_SENDER" => "b@example.com") do
        assert_equal "b@example.com", Settings.mailer_sender(default: "c@example.com")
      end
    end
  end

  # FR-027: the address links in emails are built on.
  test "link options take the configured host and drop what is unset" do
    with_credentials do
      with_env("APP_HOST" => "lockswap.example") do
        assert_equal({ host: "lockswap.example", protocol: "https" },
                     Settings.default_url_options(default_host: "fallback.example", default_protocol: "https"))
      end
      with_env do
        assert_equal({ host: "localhost", port: 3000 }, Settings.default_url_options(default_host: "localhost", default_port: 3000))
      end
    end
  end

  # The default port belongs to the default host (localhost:3000). Once APP_HOST
  # names another address — a dev box behind an HTTPS proxy — a leftover :3000
  # would break every link; only APP_PORT may set the port then.
  test "the default port applies only to the default host" do
    with_credentials do
      with_env("APP_HOST" => "lockswap-dev.example", "APP_PROTOCOL" => "https") do
        assert_equal({ host: "lockswap-dev.example", protocol: "https" },
                     Settings.default_url_options(default_host: "localhost", default_port: 3000, default_protocol: "http"))
      end
      with_env("APP_HOST" => "devbox.example", "APP_PORT" => "3000") do
        assert_equal({ host: "devbox.example", port: 3000, protocol: "http" },
                     Settings.default_url_options(default_host: "localhost", default_port: 3000, default_protocol: "http"))
      end
      with_env do
        assert_equal({ host: "localhost", port: 3000, protocol: "http" },
                     Settings.default_url_options(default_host: "localhost", default_port: 3000, default_protocol: "http"))
      end
    end
  end

  COMPLETE_SMTP = { address: "smtp.example", port: 587, user_name: "user", password: "secret" }.freeze

  # A switch that turns SMTP off whatever else is configured — so a machine can
  # keep real credentials and still send nothing (development → letter_opener).
  test "SMTP_ENABLED=false turns SMTP off even with complete credentials" do
    with_credentials(smtp: COMPLETE_SMTP) do
      with_env { assert_predicate Settings, :smtp_configured? }
      with_env("SMTP_ENABLED" => "false") do
        assert_not_predicate Settings, :smtp_enabled?
        assert_not_predicate Settings, :smtp_configured?
      end
      with_env("SMTP_ENABLED" => "0") { assert_not_predicate Settings, :smtp_configured? }
    end
  end

  test "smtp.enabled: false in the credentials turns SMTP off, and the environment can turn it back on" do
    with_credentials(smtp: COMPLETE_SMTP.merge(enabled: false)) do
      with_env { assert_not_predicate Settings, :smtp_configured? }
      with_env("SMTP_ENABLED" => "true") { assert_predicate Settings, :smtp_configured? }
    end
  end

  test "SMTP is enabled unless something says otherwise" do
    with_credentials do
      with_env { assert_predicate Settings, :smtp_enabled? }
    end
  end

  # A master key that does not match the credentials file: the mail settings
  # find nothing there rather than raising, so `bin/rails credentials:edit` —
  # which loads the environment config first — reaches Rails' own "Couldn't
  # decrypt… wrong key?" message instead of crashing in here. (The application
  # itself still refuses to boot with a wrong key: Rails reads secret_key_base
  # from the credentials, as it always has.)
  test "credentials that cannot be decrypted read as no value" do
    broken = Object.new
    def broken.dig(*) = raise(ActiveSupport::MessageEncryptor::InvalidMessage)

    original = Rails.application.method(:credentials)
    Rails.application.define_singleton_method(:credentials) { broken }

    # The warning is once per process; reset it so this test sees it, and
    # capture it so it does not leak into the test run's output.
    Settings.instance_variable_set(:@undecryptable_credentials_warned, nil)

    with_env do
      assert_output(nil, /could not be decrypted/) do
        assert_nil Settings.credential(:smtp, :address)
        assert_not_predicate Settings, :smtp_configured?
        assert_equal "fallback@example.com", Settings.mailer_sender(default: "fallback@example.com")
      end
    end
  ensure
    Rails.application.define_singleton_method(:credentials, original)
    Settings.instance_variable_set(:@undecryptable_credentials_warned, nil)
  end
end
