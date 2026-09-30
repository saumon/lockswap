# 034 FR-027/FR-029: where outgoing mail goes, who it is from, and which address
# its links point at — all configurable per deployment without changing the
# application (specs/034-email-confirmation-password-reset/contracts/mail-configuration.md).
#
# Ported from saumon/hitguessr's Hitguessr::MailerSettings, without its
# confirmation feature toggle: activation here is unconditional (research.md R1).
#
# Every value resolves ENV → encrypted credentials → default. An empty ENV value
# counts as unset, so a blank variable in a deploy file never overrides a real
# credential with nothing.
#
# Required from config/application.rb before the application class is defined,
# because the environment files and the Devise initializer both read it.
module Lockswap
  module MailerSettings
    module_function

    def smtp_settings
      {
        address: setting(:smtp, :address, env: "SMTP_ADDRESS"),
        port: integer_setting(:smtp, :port, env: "SMTP_PORT"),
        domain: setting(:smtp, :domain, env: "SMTP_DOMAIN"),
        user_name: setting(:smtp, :user_name, env: "SMTP_USERNAME"),
        password: setting(:smtp, :password, env: "SMTP_PASSWORD"),
        authentication: symbol_setting(:smtp, :authentication, env: "SMTP_AUTHENTICATION", default: :plain),
        enable_starttls_auto: boolean_setting(:smtp, :enable_starttls_auto, env: "SMTP_ENABLE_STARTTLS_AUTO", default: true),
        openssl_verify_mode: setting(:smtp, :openssl_verify_mode, env: "SMTP_OPENSSL_VERIFY_MODE")
      }.compact
    end

    # SMTP is only switched on when it is enabled and all four of these
    # resolved — a half-filled configuration is treated as none, rather than as
    # a server that will refuse every message.
    def smtp_configured?
      return false unless smtp_enabled?

      settings = smtp_settings
      %i[address port user_name password].all? { |key| settings[key].present? }
    end

    # SMTP_ENABLED / smtp.enabled: an explicit off switch, so a machine can keep
    # a complete SMTP configuration (in the credentials, say) and still send
    # nothing — development then falls back to the letter_opener inbox. On by
    # default: an instance that configured a server meant to use it.
    def smtp_enabled?
      boolean_setting(:smtp, :enabled, env: "SMTP_ENABLED", default: true)
    end

    # The default port belongs to the default host: development's localhost:3000.
    # Once APP_HOST (or app.host) names another address — typically a dev box
    # behind an HTTPS proxy — carrying :3000 over would break every link, so only
    # APP_PORT (or app.port) sets the port from then on; without one, links use
    # the protocol's standard port.
    def default_url_options(default_host:, default_port: nil, default_protocol: nil)
      host = setting(:app, :host, env: "APP_HOST")

      {
        host: host || default_host,
        port: integer_setting(:app, :port, env: "APP_PORT", default: (default_port if host.nil?)),
        protocol: setting(:app, :protocol, env: "APP_PROTOCOL", default: default_protocol)
      }.compact
    end

    def mailer_sender(default:)
      setting(:smtp, :sender, env: "SMTP_SENDER") ||
        setting(:mailer, :sender, env: "MAILER_SENDER") ||
        default
    end

    def setting(namespace, key, env:, default: nil)
      ENV[env].presence || credential(namespace, key).presence || default
    end

    def integer_setting(namespace, key, env:, default: nil)
      value = setting(namespace, key, env: env, default: default)
      value.present? ? value.to_i : nil
    end

    # Not built on #setting: its .presence would turn a credential's `false`
    # into "unset" and fall through to the default, so `enabled: false` could
    # never switch anything off.
    def boolean_setting(namespace, key, env:, default: nil)
      value = ENV[env].presence
      value = credential(namespace, key) if value.nil?
      return default if value.nil? || value == ""
      return value if value == true || value == false

      ActiveModel::Type::Boolean.new.cast(value)
    end

    def symbol_setting(namespace, key, env:, default: nil)
      value = setting(namespace, key, env: env, default: default)
      value.present? ? value.to_sym : nil
    end

    # Credentials may be absent altogether (no master key in a fresh checkout,
    # CI without secrets), or unreadable (a key that does not match the file).
    # Either way that is "no value", not an error: reading the mail settings
    # must not be what stops `bin/rails credentials:edit` — which loads this
    # environment's config before anything else — from reaching its own
    # explanation of the bad key.
    def credential(namespace, key)
      Rails.application.credentials.dig(namespace, key)
    rescue ActiveSupport::EncryptedFile::MissingKeyError
      nil
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      warn_undecryptable_credentials
      nil
    end

    # Once per process, on stderr: this runs while the environment is still
    # being configured, before Rails.logger exists.
    def warn_undecryptable_credentials
      return if @undecryptable_credentials_warned

      @undecryptable_credentials_warned = true
      Kernel.warn("[account_mail] the credentials could not be decrypted (wrong master key?); " \
                  "mail settings are read from the environment only")
    end
  end
end
