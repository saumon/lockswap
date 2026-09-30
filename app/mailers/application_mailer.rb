class ApplicationMailer < ActionMailer::Base
  # 034: the same sender Devise uses. Devise::Mailers::Helpers#headers_for drops
  # its own `from` whenever the parent mailer has a default one, so without this
  # the generated placeholder address would win for every Devise email
  # (contracts/emails.md, "Sender precedence trap"). A lambda, so it is read when
  # the mail is built, after the Devise initializer has run.
  default from: -> { Devise.mailer_sender }

  layout "mailer"
  helper :mailer

  # 034 FR-024, research.md R9: a mail is rendered by a job, outside any request,
  # where I18n.locale is the default — so the site's language setting is read
  # here, exactly as ApplicationController#switch_locale reads it for a page.
  around_action :use_site_language

  private

    def use_site_language(&block)
      I18n.with_locale(SiteLanguageSetting.current.language.to_sym, &block)
    end
end
