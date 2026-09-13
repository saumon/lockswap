# The proposal sections the homepage shows (004 FR-009). Lives here because the
# homepage has two renderers: HomeController, and LockerProfilesController when a
# rejected locker edit re-renders the same page — which must not lose the
# proposals waiting on the user just because their floor failed validation.
module LoadsHomepageProposals
  extend ActiveSupport::Concern

  private

    # Each collection is loaded with the counterpart user, since every row names
    # them; without it the page is a query per proposal (Principle IV).
    def load_homepage_proposals
      @received_pending_proposals = current_user.received_swap_proposals.pending.includes(:requester)
      @sent_pending_proposals = current_user.sent_swap_proposals.pending.includes(:recipient)
      @recently_declined_sent = unacknowledged_declines
      @exchange_in_progress = exchange_in_progress
    end

    # FR-009, FR-012: the swap this user is committed to, in whichever role. At
    # most one can exist — that is what the partial unique indexes guarantee — so
    # the first hit is the only hit. Two lookups rather than one OR: see
    # LockerSwapProposal.in_progress_for? for why.
    def exchange_in_progress
      accepted = LockerSwapProposal.accepted.includes(:requester, :recipient)

      accepted.find_by(requester_id: current_user.id) || accepted.find_by(recipient_id: current_user.id)
    end

    # FR-007: how a requester learns their proposal was declined — including when
    # the system declined it for them (FR-011). Acknowledged as it is handed to
    # the view, so the news is delivered once rather than on every later visit;
    # the history screen is where it stays available afterwards (FR-015).
    def unacknowledged_declines
      declines = current_user.sent_swap_proposals
                             .declined.where(requester_acknowledged_at: nil)
                             .includes(:recipient).to_a

      if declines.any?
        LockerSwapProposal.where(id: declines.map(&:id))
                          .update_all(requester_acknowledged_at: Time.current, updated_at: Time.current)
      end

      declines
    end
end
