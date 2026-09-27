# 033: the queue services généraux works from — every accepted swap proposal —
# and the two decisions taken on one. Separate from LockerSwapProposalsController,
# which holds the two parties' own actions on their own proposals; here an
# administrator settles someone else's exchange.
#
# No check that the administrator is not a party to the exchange: an
# administrator may settle their own (spec.md Clarifications).
class Admin::SwapValidationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  # FR-001, FR-002, research.md R7: oldest-waiting first, so nothing waits
  # indefinitely. Both parties' zones come from one batched lookup rather than
  # a query per row (Principle IV).
  def index
    @proposals = LockerSwapProposal.accepted.includes(:requester, :recipient).order(:decided_at).to_a
    @zone_names = LockerMapEntry.zone_names_for(@proposals.flat_map(&:locker_sides))
  end

  # FR-004, FR-014: exactly what the retired self-confirmation did, now
  # attributed to the administrator who did it.
  def validate
    if accepted_proposal&.confirm!(by: current_user)
      redirect_to admin_swap_validations_path, notice: t(".validated")
    else
      redirect_to admin_swap_validations_path, alert: t(".already_decided")
    end
  end

  # FR-005..FR-008: no locker moves; the comment is optional, and a blank one is
  # stored as none by decline! itself.
  def refuse
    if accepted_proposal&.decline!(params.dig(:locker_swap_proposal, :decline_comment), by: current_user)
      redirect_to admin_swap_validations_path, notice: t(".refused")
    else
      redirect_to admin_swap_validations_path, alert: t(".already_decided")
    end
  end

  private

    # FR-010, research.md R6: scoped to accepted, so a proposal another
    # administrator settled a moment ago is simply not found — said plainly
    # rather than raised as a 404.
    def accepted_proposal
      LockerSwapProposal.accepted.find_by(id: params[:id])
    end
end
