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
  include LoadsDangerZone

  # Both, in this order, as Admin::UsersController declares them: signed in at
  # all, then signed in as the super admin (029 FR-005/FR-006 — this screen
  # narrowed from every administrator to the super admin only). Declared here
  # rather than inherited from an admin base class, so a controller in this
  # namespace states its own guard and cannot lose it to a refactor somewhere
  # else. Applies to both actions below — neither scopes it with only:/except:.
  before_action :authenticate_user!
  before_action :require_super_admin!

  # FR-003, 025 FR-011: the configuration as it stands, plus the empty
  # allowed-domain form and the current language selection. The same loader
  # serves every controller that re-renders this view on a rejected write
  # (LoadsDangerZone).
  def show
    load_danger_zone
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
      load_danger_zone
      render :show, status: :unprocessable_entity
    end
  end

  private

    def site_language_setting_params
      params.require(:site_language_setting).permit(:language)
    end
end
