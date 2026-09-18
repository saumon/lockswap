# 016: the administrator's Danger Zone — settings whose blast radius is the whole
# site rather than one account. Today that is one setting: which email domains may
# register (FR-001).
#
# Read-only by design. The domains it lists are their own resource with their own
# validations, so adding and removing them lives on Admin::AllowedEmailDomains
# rather than here (research.md R3). This screen shows the configuration; it does
# not own it.
class Admin::DangerZoneController < ApplicationController
  # Both, in this order, as Admin::UsersController declares them: signed in at
  # all, then signed in as an administrator (FR-002). Declared here rather than
  # inherited from an admin base class, so a controller in this namespace states
  # its own guard and cannot lose it to a refactor somewhere else.
  before_action :authenticate_user!
  before_action :require_admin!

  # FR-003: the configuration as it stands, plus the empty form that adds to it.
  #
  # Ordered by domain rather than by insertion, because an administrator scanning
  # for one is reading a list, not a history. Admin::AllowedEmailDomainsController
  # re-renders this view on a rejected addition, so both instance variables are
  # also set there — see the note on its #create.
  def show
    @allowed_email_domains = AllowedEmailDomain.order(:domain)
    @allowed_email_domain = AllowedEmailDomain.new
  end
end
