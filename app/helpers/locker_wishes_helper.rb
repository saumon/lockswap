# 017: the addresses behind the floor filter choices.
module LockerWishesHelper
  # The screen for one choice on one axis, with every other axis left exactly as
  # it is — so clearing the floor people are looking for does not also clear the
  # floor they are on (FR-017).
  #
  # A blank `looking_for` is dropped rather than sent as an empty parameter,
  # which is what makes clearing that axis land on the bare /locker_wishes
  # rather than on "?looking_for=" (FR-018).
  #
  # 019: `current_floor` is the one exception — it is kept as an explicit empty
  # string rather than dropped, because absent and "explicitly All floors" mean
  # different things for that axis (LockerWishesController#current_floor_selection):
  # dropping it here would let the very next click silently lose a deliberate
  # "All floors" choice back to the viewer's wish (research R4).
  #
  # `floor` is nil for the "All floors" choice.
  def locker_wish_filter_path(filters, axis, floor)
    selections = filters.to_h { |key, filter| [ key, filter.selection ] }.merge(axis => floor)

    locker_wishes_path(
      looking_for: selections[:looking_for].presence,
      current_floor: selections[:current_floor].presence || ""
    )
  end
end
