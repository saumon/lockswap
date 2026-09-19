# Declaring, browsing, and cancelling locker search wishes (003), and narrowing
# the list by floor (017).
# Deliberately separate from HomeController and LockerProfilesController: this is
# a different concern — what people are looking for, not what they already have.
class LockerWishesController < ApplicationController
  # FR-013: every action here — viewing the list included — is for logged-in
  # users only; an anonymous visitor is sent to the login page instead.
  before_action :authenticate_user!

  # 017: the two axes, and where each one's floor arrives from. The keys are the
  # query parameters, so this is also what the filtered address looks like.
  FILTER_AXES = %i[looking_for current_floor].freeze

  # 017 FR-019: the two forms in the declare panel, named so that the fields
  # carrying the filters — which live inside the frame, where a filter change
  # refreshes them — can attach themselves to forms outside it. The ids are here
  # rather than written twice in the views, so the two ends cannot drift apart.
  DECLARE_FORM_ID = "locker-wish-form".freeze
  CANCEL_FORM_ID = "locker-wish-cancel".freeze

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
      # 019 FR-003: the redirect always reflects the just-saved floor, even
      # over a current_floor the viewer had set manually before declaring
      # (research R3) — not left to current_floor_selection's general
      # absent-key fallback to produce the right answer a request later.
      redirect_to locker_wishes_path(filter_selections.merge(current_floor: @locker_wish.saved_floor)),
        notice: "Locker search saved."
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

    # 019 FR-004: drop current_floor from the redirect target entirely rather
    # than carrying forward whatever was submitted — there is no wish left to
    # derive it from either way, so the next render's fallback already lands on
    # "All floors" (research R3); dropping it (rather than setting it to "")
    # keeps this redirect identical to 017's when no wish existed to begin with.
    redirect_to locker_wishes_path(filter_selections.except(:current_floor)),
      notice: "Locker search cancelled."
  end

  private

    # The list itself, plus what the viewer may do with each row. Both rendering
    # paths need all three, since a rejected declare re-renders the whole page —
    # which is also why 017's filters are built here rather than in #index: a
    # rejected declare must come back filtered exactly as it was (FR-019).
    # The two eligibility answers are fetched once rather than per row, which
    # would be a query per wish (Principle IV).
    def load_wish_list
      @floor_filters = build_floor_filters
      @locker_wishes = filtered_locker_wishes
      @viewer_in_progress = LockerSwapProposal.in_progress_for?(current_user)
      @pending_recipient_ids = current_user.sent_swap_proposals.pending.pluck(:recipient_id)

      # 018 FR-001/FR-003/FR-004: read past any unsaved edit, same reason as
      # everywhere else `saved_floor` is used (research R1). `current_user` and
      # `current_user.locker_wish` are both already loaded above and by
      # `own_locker_wish`, so neither read costs a query.
      @viewer_current_floor = current_user.saved_floor
      @viewer_wish_floor = current_user.locker_wish&.saved_floor
    end

    # An unsaved wish stands in for "has not declared yet", so the view has
    # something to build the declare form from either way.
    def own_locker_wish
      current_user.locker_wish || current_user.build_locker_wish
    end

    # 017 FR-006: each axis offers the floors found across *every* active wish,
    # never only those left after the other axis has been applied — so setting one
    # filter never adds to, removes from or reorders what the other offers. That
    # is why the choices come from `LockerWish.active` and not from the relation
    # below. Two bounded DISTINCT queries, one per axis: at most one row per
    # floor, whatever the number of wishes (Principle IV).
    def build_floor_filters
      {
        looking_for: FloorFilter.new(
          selection: filter_selection(:looking_for), available: LockerWish.looked_for_floors
        ),
        current_floor: FloorFilter.new(
          selection: current_floor_selection, available: LockerWish.owner_floors
        )
      }
    end

    # 019 FR-001/FR-002/FR-008: absent from the address entirely means "not yet
    # decided this visit" — derived from the viewer's own active wish.
    # Present, even blank (an explicit "All floors"), means it was already
    # decided — by a filter click, by this feature's own create/destroy
    # redirect, or by Back/Forward reproducing an address from earlier in the
    # visit — and is respected exactly as it arrives. `current_user.locker_wish`
    # is already loaded by `own_locker_wish` on every path that reaches here, so
    # this costs no extra query (research R2).
    def current_floor_selection
      params.key?(:current_floor) ? filter_selection(:current_floor) : current_user.locker_wish&.saved_floor
    end

    # FR-010/FR-011: an axis left on "all floors" is a no-op, so the two scopes
    # compose into the intersection when both are set, and into the single-axis
    # list when only one is.
    def filtered_locker_wishes
      LockerWish.active
                .looking_for(@floor_filters[:looking_for].selection)
                .owner_on_floor(@floor_filters[:current_floor].selection)
    end

    # FR-020: a floor arriving in the address is matched exactly as it came, and
    # anything that is not a plain string — `?looking_for[]=3` — is no filter at
    # all rather than an error. Read separately from locker_wish_params, which
    # stays exactly as wide as it was: nothing here can reach the wish record.
    def filter_selection(axis)
      value = params[axis]

      value.is_a?(String) ? value : nil
    end

    # FR-019: what the declare and cancel redirects carry, so the screen the
    # viewer lands back on is still filtered the way they left it. Blank axes are
    # dropped rather than sent empty, so an unfiltered view redirects to the bare
    # path it always did.
    def filter_selections
      FILTER_AXES.index_with { |axis| filter_selection(axis) }.compact_blank
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
