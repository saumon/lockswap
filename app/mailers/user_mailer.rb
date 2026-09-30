# 034: Devise's own mailer, with one difference. The email-change confirmation
# (spec User Story 6) is the same Devise action as the activation email, so it
# would otherwise share its subject — "Activate your LockSwap account" sent to
# someone whose account has been active for months.
#
# Devise::Mailers::Helpers#headers_for merges the caller's options last
# (devise 5.0.4, lib/devise/mailers/helpers.rb:44), so a subject passed here
# replaces the default one.
class UserMailer < Devise::Mailer
  helper :mailer

  def confirmation_instructions(record, token, opts = {})
    opts[:subject] = I18n.t("mailer.reconfirmation_instructions.subject") if record.pending_reconfirmation?

    super
  end
end
