# One axis of the locker wish list's floor filter (017). Plain Ruby, no table of
# its own: it is handed the floors that were found and the value that was asked
# for, and answers what one filter bar needs to render.
#
# Two instances serve one request — the floor people are looking for, and the
# floor they currently hold a locker on. Everything both axes do identically lives
# here rather than twice in the view: the order the choices are offered in
# (FR-007), and keeping a selection visible when no wish carries it any more
# (FR-015, FR-020).
class FloorFilter
  # As it arrived, or nil for "all floors". Deliberately not trimmed or otherwise
  # rewritten: floors are free text and the spec rules out normalisation, so a
  # value is matched exactly as it was recorded.
  attr_reader :selection

  # A blank selection is how a browser sends an empty field (`?looking_for=`), and
  # it means all floors rather than "the floor named empty string" (FR-003).
  def initialize(selection:, available:)
    @selection = selection.presence
    @available = available
  end

  def filtering? = !@selection.nil?

  def current?(floor) = floor == @selection

  # The floors to offer, in FR-007 order. A selection that is in force but carries
  # no wish — because they were all cancelled, or because the value arrived in the
  # address — is appended rather than dropped, so the viewer can always see what
  # they are filtered on and click away from it (FR-015, FR-020). It is offered to
  # nobody choosing afresh, since it is not among the available floors.
  def choices
    offered = @available.compact_blank.uniq.sort_by { |floor| self.class.sort_key(floor) }

    return offered unless filtering?

    offered.include?(@selection) ? offered : offered + [ @selection ]
  end

  # FR-007: floors that read as whole numbers first, ascending, then the rest
  # alphabetically. The trailing raw string settles ties — "3" and "03" are the
  # same number, and the spec's edge case requires their order not to vary between
  # displays.
  #
  # The explicit base 10 is load-bearing. Integer("010") with no base reads the
  # leading zero as octal and returns 8, which would offer "010" before "9".
  def self.sort_key(floor)
    number = Integer(floor, 10, exception: false)

    [ number ? 0 : 1, number || 0, floor ]
  end
end
