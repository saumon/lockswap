# 016: the administrator's Danger Zone — settings whose blast radius is the whole
# site rather than one account. That started as one setting (which email domains
# may register, FR-001) and 025 adds a second, the site language.
#
# The allowed-domains section stays read-only here by design — those rows are
# their own resource with their own validations, so adding and removing them
# lives on Admin::AllowedEmailDomainsController rather than here (research.md
# R3). The language setting is the opposite shape: one value, not a list, and
# it IS this screen's own state rather than a resource with independent
# identity, so #update lives directly on this controller (research.md R6).
class Admin::DangerZoneController < ApplicationController
  # Both, in this order, as Admin::UsersController declares them: signed in at
  # all, then signed in as an administrator (FR-002). Declared here rather than
  # inherited from an admin base class, so a controller in this namespace states
  # its own guard and cannot lose it to a refactor somewhere else. Applies to
  # both actions below — neither scopes it with only:/except:.
  before_action :authenticate_user!
  before_action :require_admin!

  # FR-003, 025 FR-011: the configuration as it stands, plus the empty
  # allowed-domain form and the current language selection.
  #
  # Ordered by domain rather than by insertion, because an administrator scanning
  # for one is reading a list, not a history. Admin::AllowedEmailDomainsController
  # and #update below re-render this view on a rejected write, so all three
  # instance variables are also set there.
  def show
    @allowed_email_domains = AllowedEmailDomain.order(:domain)
    @allowed_email_domain = AllowedEmailDomain.new
    @site_language_setting = SiteLanguageSetting.current
  end

  # 025 FR-001/FR-011: the only write this controller owns directly. Success
  # redirects back to #show with a flash notice named in the *new* language —
  # I18n.t(..., locale:) rather than the ambient I18n.locale, because this
  # request's around_action already fixed I18n.locale to the *old* value for
  # its whole duration before this action ran (research.md R2), and the
  # contract requires the confirmation to read in whichever language is now
  # current (contracts/danger-zone-language.md).
  def update
    @site_language_setting = SiteLanguageSetting.current

    if @site_language_setting.update(site_language_setting_params)
      new_language = @site_language_setting.language
      language_name = t("admin.danger_zone.show.languages.#{new_language}", locale: new_language)
      redirect_to admin_danger_zone_path,
        notice: t("admin.danger_zone.show.language_updated", language: language_name, locale: new_language)
    else
      @allowed_email_domains = AllowedEmailDomain.order(:domain)
      @allowed_email_domain = AllowedEmailDomain.new
      render :show, status: :unprocessable_entity
    end
  end

  private

    def site_language_setting_params
      params.require(:site_language_setting).permit(:language)
    end
end
