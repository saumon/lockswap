require "test_helper"

# 012 FR-018: one breakpoint, site-wide.
#
# The requirement is that the layout switches between its narrow and wide
# treatments at a single consistent value, so that there is no width at which
# one region of the site is in one treatment and another region is in the other.
# The only way that stays true is if no second value ever gets added, which is
# not something review reliably catches — so it is asserted here instead.
#
# No browser needed: this reads the stylesheet as text and runs in the unit
# suite, where it costs nothing and fails immediately.
class StylesheetBreakpointTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/tailwind/application.css")

  # 48rem is the breakpoint; 47.999rem is its exclusive complement, used for
  # narrow-only rules so the two never overlap at 768px exactly (FR-018b).
  ALLOWED_WIDTHS = [ "48rem", "47.999rem" ].freeze

  test "every width-based media query uses the one breakpoint" do
    offenders = width_media_queries.reject do |query|
      query.scan(/[\d.]+rem|\d+px/).all? { |width| ALLOWED_WIDTHS.include?(width) }
    end

    assert_empty offenders,
      "FR-018 allows only #{ALLOWED_WIDTHS.join(" and ")} in a media query. Found: " +
        offenders.map(&:inspect).join(", ")
  end

  test "the breakpoint is actually used" do
    assert_not_empty width_media_queries,
      "no width-based media query found at all — the responsive layout is missing"
  end

  private

    # Comments are stripped first. The breakpoint convention block documents the
    # two allowed forms by writing them out, and a naive scan would read those
    # examples as real rules — or, worse, would pass only because the examples
    # happen to be the allowed values, and would keep passing if someone
    # documented a third.
    def width_media_queries
      source = STYLESHEET.read.gsub(%r{/\*.*?\*/}m, "")
      source.scan(/@media[^{]*(?:min-width|max-width)[^{]*/).map(&:strip)
    end
end
