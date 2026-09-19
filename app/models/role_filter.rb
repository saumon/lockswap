# 020: the role axis of the admin Users screen's filter bar. A deliberately
# smaller sibling of FloorFilter — it shares just enough of its shape (selection,
# filtering?, current?, choices) to be rendered by the same link-group partial,
# without FloorFilter's sorting or "keep a vanished selection visible" logic.
# Neither applies here: FR-006 fixes the choice pair regardless of which roles
# are actually held by registered accounts, so there is nothing to derive and
# nothing that can ever be absent from the set.
class RoleFilter
  CHOICES = %w[Admin Standard].freeze

  # As it arrived, or nil for "all roles" — same convention as FloorFilter.
  attr_reader :selection

  def initialize(selection:)
    @selection = selection.presence
  end

  def filtering? = !@selection.nil?

  def current?(choice) = choice == @selection

  def choices = CHOICES
end
