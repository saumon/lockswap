# Everything the Danger Zone screen draws (016, 025, 030). Lives here because the
# screen has several renderers: Admin::DangerZoneController#show, and every
# controller whose write belongs to one of its sections and re-renders it on a
# refusal — the language (DangerZoneController#update), the allowed domains
# (Admin::AllowedEmailDomainsController), and from 030 the floor list and the
# locker number format. Each used to reload the other sections itself; with five
# sections that is one list to keep in step instead of four (research.md R7).
module LoadsDangerZone
  extend ActiveSupport::Concern

  private

    # ||= is load-bearing: the controller whose write was refused has already
    # assigned its own section's object — holding the rejected input and its
    # errors — and that object, not a fresh copy from the database, is what the
    # re-render must show. Every other section is loaded as it stands.
    #
    # The allowed domains are ordered by domain rather than by insertion, because
    # an administrator scanning for one is reading a list, not a history.
    def load_danger_zone
      @allowed_email_domains ||= AllowedEmailDomain.order(:domain)
      @allowed_email_domain ||= AllowedEmailDomain.new
      @site_language_setting ||= SiteLanguageSetting.current
      @site_floor_list ||= SiteFloorList.current
      @locker_number_format ||= LockerNumberFormat.current
    end
end
