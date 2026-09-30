require "test_helper"

# 034 contracts/emails.md: the four account emails, as sent.
class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:alice)
  end

  # ---- activation (User Story 1) -------------------------------------------

  test "the activation email carries its link as a button and as text, in both parts" do
    mail = UserMailer.confirmation_instructions(@user, "tok")

    # FR-026
    assert_predicate mail, :multipart?
    assert mail.html_part && mail.text_part

    assert_equal "Activate your LockSwap account", mail.subject
    assert_equal [ @user.email ], mail.to

    [ mail.html_part.decoded, mail.text_part.decoded ].each do |body|
      # FR-002, FR-027: the account's own link, on the configured host.
      assert_includes body, "http://example.com/users/confirmation?confirmation_token=tok"
      # FR-025
      assert_includes body, "This link works for 24 hours."
      assert_includes body, "If you did not create this account, ignore this email"
    end
  end

  # contracts/emails.md, "Sender precedence trap": the parent mailer's default
  # sender must be the real one, not the generated placeholder.
  test "the activation email comes from the configured sender" do
    mail = UserMailer.confirmation_instructions(@user, "tok")

    assert_equal Mail::Address.new(Devise.mailer_sender).address, mail.from.first
    assert_not_includes mail.from, "from@example.com"
  end

  # FR-024: written in the site's language at the time it is sent.
  test "the activation email follows the site language" do
    SiteLanguageSetting.current.update!(language: "fr")

    mail = UserMailer.confirmation_instructions(@user, "tok")

    assert_equal "Activez votre compte LockSwap", mail.subject
    assert_includes mail.text_part.decoded, "Ce lien est valable 24 heures."
  end

  # CLAUDE.md: no colour literal in a template — the email templates take their
  # colours from MailerHelper by token name.
  test "no email template spells out a colour" do
    templates = Dir[Rails.root.join("app/views/devise/mailer/*.erb")] +
                Dir[Rails.root.join("app/views/layouts/mailer.*.erb")]

    assert_not_empty templates
    templates.each do |path|
      assert_no_match(/#\h{6}\b/, File.read(path), "#{path} contains a raw hex colour")
    end
  end

  # ---- password reset (User Story 3) ---------------------------------------

  test "the reset email carries a six-hour, single-use link" do
    mail = UserMailer.reset_password_instructions(@user, "tok")

    assert_predicate mail, :multipart?
    assert_equal "Reset your LockSwap password", mail.subject
    [ mail.html_part.decoded, mail.text_part.decoded ].each do |body|
      assert_includes body, "http://example.com/users/password/edit?reset_password_token=tok"
      assert_includes body, "This link works for 6 hours, and only once."
      assert_includes body, "your password will not change"
    end
  end

  # FR-039: a notice of the change, with its time, and nothing to click.
  test "the password-changed email says when, and carries no link" do
    travel_to Time.zone.local(2026, 10, 1, 9, 30) do
      mail = UserMailer.password_change(@user)

      assert_predicate mail, :multipart?
      assert_equal "Your LockSwap password was changed", mail.subject
      [ mail.html_part.decoded, mail.text_part.decoded ].each do |body|
        assert_includes body, I18n.l(Time.current, format: :long)
        assert_includes body, "contact an administrator"
        assert_no_match %r{https?://}, body
      end
    end
  end

  # ---- email change (User Story 6) -----------------------------------------

  # The same Devise action as activation, sent to the new address with its own
  # subject and wording — not "Activate your account" to someone long active.
  test "the email-change confirmation has its own subject and wording" do
    @user.update_columns(unconfirmed_email: "alice.new@example.com")

    mail = UserMailer.confirmation_instructions(@user, "tok", to: @user.unconfirmed_email)

    assert_equal [ "alice.new@example.com" ], mail.to
    assert_equal "Confirm your new LockSwap email address", mail.subject
    assert_includes mail.text_part.decoded, "Confirm your new address"
    assert_not_includes mail.text_part.decoded, "Activate your account"

    SiteLanguageSetting.current.update!(language: "fr")
    assert_equal "Confirmez votre nouvelle adresse e-mail LockSwap",
                 UserMailer.confirmation_instructions(@user, "tok", to: @user.unconfirmed_email).subject
  end
end
