# The swap proposal lifecycle (004): proposing, withdrawing, accepting,
# declining, confirming, and the history screen. Deliberately separate from
# LockerWishesController and HomeController — those two only surface proposals,
# the state transitions all live here and on the model.
class LockerSwapProposalsController < ApplicationController
  # FR-016: every action here is for logged-in users only; an anonymous visitor
  # is sent to the login page instead.
  before_action :authenticate_user!

  # FR-015: every proposal this user was party to, newest first — the review
  # surface, deliberately read-only. Both roles are fetched separately and merged
  # rather than asked for with an OR: see LockerSwapProposal.in_progress_for?.
  def index
    @proposals = (current_user.sent_swap_proposals.includes(:recipient).to_a +
                  current_user.received_swap_proposals.includes(:requester).to_a)
                 .sort_by(&:created_at).reverse
  end

  # FR-001: sent from the wish list, and answered back on the wish list, so the
  # refusals below land next to the row that prompted them.
  def create
    proposal = current_user.sent_swap_proposals.build(recipient_id: proposal_params[:recipient_id])

    if save_proposal(proposal)
      redirect_to locker_wishes_path, notice: "Swap proposal sent."
    else
      redirect_to locker_wishes_path, alert: refusal_for(proposal)
    end
  end

  # FR-019: withdrawing. Scoped to the user's own pending sent proposals, so
  # someone else's — or one already decided — is simply not theirs to find
  # (FR-020), rather than being found and then refused.
  def destroy
    current_user.sent_swap_proposals.pending.find(params[:id]).withdraw!

    redirect_to root_path, notice: "Swap proposal withdrawn."
  end

  # FR-005, FR-006: the recipient's decision, and only theirs — the same scoping
  # as above, through the other side of the association (FR-010).
  def accept
    if pending_received_proposal.accept!
      redirect_to root_path, notice: "Swap proposal accepted."
    else
      # The eligibility re-check inside accept! lost a race: somebody involved
      # entered another exchange first (FR-003, FR-004).
      redirect_to root_path,
                  alert: "That proposal can no longer be accepted — someone involved already has an exchange in progress."
    end
  end

  # FR-005, FR-007, FR-008: the comment is optional, so a missing one is not a
  # missing parameter.
  def decline
    pending_received_proposal.decline!(params.dig(:locker_swap_proposal, :decline_comment))

    redirect_to root_path, notice: "Swap proposal declined."
  end

  # FR-012, FR-013: only the recipient who accepted can say the swap actually
  # happened. Scoping to their own accepted received proposals is what enforces
  # that — to the requester it is simply not there to confirm (FR-014).
  def confirm
    current_user.received_swap_proposals.accepted.find(params[:id]).confirm!

    redirect_to root_path, notice: "Exchange confirmed — your locker details have been swapped."
  end

  private

    def pending_received_proposal
      current_user.received_swap_proposals.pending.find(params[:id])
    end

    def proposal_params
      params.expect(locker_swap_proposal: [ :recipient_id ])
    end

    # Two submissions can both pass the model's duplicate check before either
    # commits, so the partial unique index is the real guarantee (FR-018). The
    # loser is folded back into the ordinary refusal rather than surfacing a 500.
    def save_proposal(proposal)
      proposal.save
    rescue ActiveRecord::RecordNotUnique
      proposal.errors.add(:recipient, "already has a pending proposal from you")
      false
    end

    # The model already phrased each refusal; this just picks the first one and
    # makes it a sentence, so every rejection reads the same way (Principle III).
    def refusal_for(proposal)
      error = proposal.errors.first

      return error.message if error.attribute == :base

      "That person #{error.message}."
    end
end
