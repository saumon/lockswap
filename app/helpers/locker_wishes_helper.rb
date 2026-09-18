# 017: the addresses behind the floor filter choices.
module LockerWishesHelper
  # The screen for one choice on one axis, with every other axis left exactly as
  # it is — so clearing the floor people are looking for does not also clear the
  # floor they are on (FR-017).
  #
  # A blank value is dropped rather than sent as an empty parameter, which is what
  # makes clearing every axis land on the bare /locker_wishes rather than on
  # "?looking_for=&current_floor=" (FR-018).
  #
  # `floor` is nil for the "All floors" choice.
  def locker_wish_filter_path(filters, axis, floor)
    selections = filters.to_h { |key, filter| [ key, filter.selection ] }

    locker_wishes_path(selections.merge(axis => floor).compact_blank)
  end
end
