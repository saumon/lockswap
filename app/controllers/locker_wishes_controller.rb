# Declaring, browsing, and cancelling locker search wishes (003).
# Deliberately separate from HomeController and LockerProfilesController: this is
# a different concern — what people are looking for, not what they already have.
class LockerWishesController < ApplicationController
  # FR-013: every action here — viewing the list included — is for logged-in
  # users only; an anonymous visitor is sent to the login page instead.
  before_action :authenticate_user!

  def index
    @locker_wish = own_locker_wish
    load_wish_list
  end

  # FR-001, FR-004: the same action records a first wish and moves an existing
  # one, so a user can never accumulate two.
  def create
    @locker_wish = own_locker_wish
    @locker_wish.floor = locker_wish_params[:floor]

    if save_locker_wish
      redirect_to locker_wishes_path, notice: "Locker search saved."
    else
      load_wish_list
      render :index, status: :unprocessable_entity
    end
  end

  # FR-009, FR-010: cancelling removes the wish outright, so it stops appearing
  # in the list for everyone. Someone with nothing to cancel is not an error —
  # there is simply nothing to do.
  def destroy
    current_user.locker_wish&.destroy

    redirect_to locker_wishes_path, notice: "Locker search cancelled."
  end

  private

    # The list itself, plus what the viewer may do with each row. Both rendering
    # paths need all three, since a rejected declare re-renders the whole page.
    # The two eligibility answers are fetched once rather than per row, which
    # would be a query per wish (Principle IV).
    def load_wish_list
      @locker_wishes = all_locker_wishes
      @viewer_in_progress = LockerSwapProposal.in_progress_for?(current_user)
      @pending_recipient_ids = current_user.sent_swap_proposals.pending.pluck(:recipient_id)
    end

    # An unsaved wish stands in for "has not declared yet", so the view has
    # something to build the declare form from either way.
    def own_locker_wish
      current_user.locker_wish || current_user.build_locker_wish
    end

    # FR-011/FR-012: every active wish, oldest declaration first. The rows each
    # report their owner's saved floor and locker, so the users are loaded up
    # front rather than one query per row.
    #
    # 004 Edge Case: someone mid-swap is no longer an open invitation, so their
    # wish drops out of the list until the exchange completes — which destroys
    # the wish outright. The wish row itself is never touched here.
    def all_locker_wishes
      LockerWish.where.not(user_id: LockerSwapProposal.in_progress_user_ids)
                .includes(:user).order(created_at: :asc)
    end

    def locker_wish_params
      params.expect(locker_wish: [ :floor ])
    end

    # Two declares for one account can both get past the lookup above before
    # either commits, so the unique index is the real guarantee (FR-003, SC-003).
    # The loser folds its floor into the row that won rather than reporting a
    # conflict: a second declare is defined as moving the wish anyway (FR-004).
    def save_locker_wish
      @locker_wish.save
    rescue ActiveRecord::RecordNotUnique
      @locker_wish = current_user.reload.locker_wish
      @locker_wish.update(floor: locker_wish_params[:floor])
    end
end
