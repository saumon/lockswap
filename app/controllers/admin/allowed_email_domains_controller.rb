# 016 FR-003: the two writes behind the Danger Zone screen — adding a domain to
# the allow-list and taking one off it.
#
# No #update: changing a domain is remove-then-add, which leaves this resource
# with exactly the two operations the spec describes and no half-edited state to
# validate. No #index either — the list is the Danger Zone screen, which is a
# screen and not this resource (research.md R3).
class Admin::AllowedEmailDomainsController < ApplicationController
  # FR-002: the same pair that guards the screen guards the writes, so what is
  # hidden from the navigation is also refused at the address. Restated here
  # rather than inherited, for the reason Admin::DangerZoneController gives.
  before_action :authenticate_user!
  before_action :require_admin!

  # Between the screen being drawn and a button on it being pressed, another
  # administrator can have removed the same domain. The outcome asked for already
  # holds, so this is a notice and not an alert — the same reading 015 took for
  # granting rights to an account somebody else had just promoted.
  DOMAIN_GONE_MESSAGE = "That domain had already been removed.".freeze

  def create
    @allowed_email_domain = AllowedEmailDomain.new(allowed_email_domain_params)

    if @allowed_email_domain.save
      redirect_to admin_danger_zone_path, notice: "#{@allowed_email_domain.domain} may now register."
    else
      # Re-render the screen the administrator was on, with the rejected entry
      # still in the field and the reason above it (FR-008) — the same shape
      # LockerProfilesController#update uses for a rejected edit. The list has to
      # be reloaded because this action never ran #show: without it the screen
      # would come back with its existing configuration missing, which reads as
      # the failed addition having wiped it.
      @allowed_email_domains = AllowedEmailDomain.order(:domain)
      render "admin/danger_zone/show", status: :unprocessable_entity
    end
  end

  # FR-003, User Story 2: taking a domain off the list — and, when it is the last
  # one, lifting the restriction altogether (FR-004).
  def destroy
    domain = AllowedEmailDomain.find_by(id: params[:id])

    # find_by and not find, so a domain someone else removed a moment ago is a
    # message rather than a 404: the administrator did nothing wrong and belongs
    # back on the screen either way.
    return redirect_to admin_danger_zone_path, notice: DOMAIN_GONE_MESSAGE if domain.nil?

    domain.destroy

    redirect_to admin_danger_zone_path, notice: removal_notice_for(domain)
  end

  private

    def allowed_email_domain_params
      params.expect(allowed_email_domain: [ :domain ])
    end

    # Says what the removal opened up, not just what it deleted. Taking the last
    # domain off the list reopens the site to every domain — a bigger change than
    # "one row gone", and not one an administrator should have to infer from an
    # empty table (FR-004).
    def removal_notice_for(domain)
      if AllowedEmailDomain.exists?
        "#{domain.domain} may no longer register."
      else
        "#{domain.domain} removed. Registration is open to any email domain again."
      end
    end
end
