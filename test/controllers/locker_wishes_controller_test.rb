require "test_helper"

# Covers the parts of 003 spec.md that the browser tests cannot reach: the
# concurrent-declare race behind FR-004, and the HTTP verbs FR-013 has to refuse
# to an anonymous visitor.
class LockerWishesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # FR-004: two declares for one account can both pass the already-has-a-wish
  # lookup before either commits, and the unique index then rejects the loser.
  # The loser must still end up doing what a second declare is defined to do —
  # leave one wish holding the floor just submitted — not report a conflict the
  # user cannot act on.
  test "a declare that loses the database race still leaves one wish at the submitted floor" do
    sign_in users(:alice)

    with_the_first_save_losing_the_race(to: users(:alice)) do
      post locker_wish_path, params: { locker_wish: { floor: "4" } }
    end

    # 019 FR-003: every successful declare's redirect now carries the new
    # floor as "Their floor," incidental to what this test is actually about.
    assert_redirected_to locker_wishes_path(current_floor: "4")
    assert_equal 1, LockerWish.where(user: users(:alice)).count
    assert_equal "4", users(:alice).reload.locker_wish.floor
  end

  # User Story 1, Acceptance Scenarios 3 and 4 (FR-002): already holding a locker
  # neither blocks a wish nor is changed by one — that is what a swap is. This
  # lived in the browser suite until ChromeDriver's dropped keystrokes and clicks
  # made it the one scenario that would not hold still; here nothing is dropped.
  test "a user who already has a locker can declare a wish and keeps the locker" do
    sign_in users(:dave)

    assert_difference -> { LockerWish.count }, 1 do
      post locker_wish_path, params: { locker_wish: { floor: "9" } }
    end

    # 019 FR-003: as above — the redirect now carries the declared floor.
    assert_redirected_to locker_wishes_path(current_floor: "9")
    assert_equal "9", users(:dave).reload.locker_wish.floor
    assert_equal "D07", users(:dave).locker_number
  end

  # User Story 3, Acceptance Scenario 2: there is simply nothing to cancel.
  test "cancelling with no active wish changes nothing and does not error" do
    sign_in users(:alice)

    assert_no_difference -> { LockerWish.count } do
      delete locker_wish_path
    end

    assert_redirected_to locker_wishes_path
  end

  # FR-013 for the two verbs a browser test cannot issue on its own.
  test "an anonymous visitor cannot declare a wish" do
    assert_no_difference -> { LockerWish.count } do
      post locker_wish_path, params: { locker_wish: { floor: "4" } }
    end

    assert_redirected_to new_user_session_path
  end

  test "an anonymous visitor cannot cancel a wish" do
    assert_no_difference -> { LockerWish.count } do
      delete locker_wish_path
    end

    assert_redirected_to new_user_session_path
  end

  # --- 017: the floor filters -------------------------------------------------

  # FR-010: one axis set, the other on all floors.
  test "the looking-for filter narrows the list to wishes for that floor" do
    sign_in users(:dave)

    get locker_wishes_path(looking_for: "3")

    assert_select "#locker-wish-row-#{users(:karl).id}"
    assert_select "#locker-wish-row-#{users(:bob).id}", false
    assert_select "#locker-wish-row-#{users(:carol).id}", false
  end

  # FR-010, FR-012: someone who has never saved a floor matches no floor.
  test "the current-floor filter narrows the list to people saved on that floor" do
    sign_in users(:dave)

    get locker_wishes_path(current_floor: "3")

    assert_select "#locker-wish-row-#{users(:bob).id}"
    assert_select "#locker-wish-row-#{users(:karl).id}", false
    assert_select "#locker-wish-row-#{users(:judy).id}", false
  end

  # FR-011: both set is the intersection, not the union. karl is looking for 3 but
  # has no floor of his own; bob is on floor 3 but looking for 7. Neither survives
  # a filter that asks for both at once.
  test "both filters together show only the wishes matching both" do
    sign_in users(:dave)

    get locker_wishes_path(looking_for: "10", current_floor: "10")

    assert_select "#locker-wish-row-#{users(:judy).id}"
    assert_select "#locker-wish-row-#{users(:bob).id}", false
    assert_select "#locker-wish-row-#{users(:karl).id}", false
  end

  # FR-006: the choices come from every active wish, never from what is left once
  # the other axis has been applied. The risk this guards is the controller being
  # "improved" to derive the choices from the filtered relation, which would make
  # choices appear and vanish as the viewer filters.
  test "setting one filter does not change what the other offers" do
    sign_in users(:dave)

    get locker_wishes_path
    unfiltered = filter_choices_offered

    get locker_wishes_path(looking_for: "10")

    assert_equal unfiltered, filter_choices_offered
  end

  # FR-003: `?looking_for=` is how a browser sends an empty field. It means all
  # floors, not "the floor named empty string".
  test "a blank filter value is the same as no filter at all" do
    sign_in users(:dave)

    get locker_wishes_path(looking_for: "", current_floor: "")

    assert_select "#locker-wish-list-no-match", false
    LockerWish.active.each { |wish| assert_select "#locker-wish-row-#{wish.user_id}" }
  end

  # FR-020: junk in the address is an empty result the viewer can see and undo —
  # not an error, and not a silent fallback to the unfiltered list.
  test "a floor in the address that matches nothing shows an empty result, not everyone" do
    sign_in users(:dave)

    get locker_wishes_path(looking_for: "NOPE")

    assert_response :success
    assert_select "#locker-wish-list-no-match"
    assert_select "#locker-wish-list-empty", false
    assert_select "#locker-wish-row-#{users(:bob).id}", false
  end

  # FR-015: and it is still shown as the choice in force, so it can be cleared.
  test "a floor matching nothing is still offered as the current selection" do
    sign_in users(:dave)

    get locker_wishes_path(looking_for: "NOPE")

    assert_select "#locker-wish-filter-looking-for a[aria-current='true']", text: "NOPE"
  end

  # FR-020: anything that is not a plain string is no filter, rather than an error.
  test "a non-string filter value is ignored rather than raising" do
    sign_in users(:dave)

    get locker_wishes_path(looking_for: [ "3" ])

    assert_response :success
    assert_select "#locker-wish-row-#{users(:bob).id}"
  end

  # --- 019: pre-filling "Their floor" from the viewer's own wish -------------

  # FR-001: a fresh, unfiltered request derives "Their floor" from the
  # viewer's own active wish rather than defaulting to "All floors".
  test "a fresh request with no current_floor param derives it from the viewer's active wish" do
    sign_in users(:bob) # wish floor "7"

    get locker_wishes_path

    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "7"
    assert_select "#locker-wish-row-#{users(:henry).id}"
    assert_select "#locker-wish-row-#{users(:karl).id}", false
  end

  # FR-002: the same request, for a viewer with no active wish, still defaults
  # to "All floors".
  test "a fresh request derives All floors when the viewer has no active wish" do
    sign_in users(:dave) # no wish

    get locker_wishes_path

    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "All floors"
  end

  # FR-008/contract "Request -> selection": an explicit value in the address —
  # even one that differs from the viewer's own wish — is respected exactly as
  # 017 already respects it, not overridden by the derivation.
  test "an explicit current_floor wins over the viewer's own wish floor" do
    sign_in users(:bob) # wish floor "7"

    get locker_wishes_path(current_floor: "3")

    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "3"
    assert_select "#locker-wish-row-#{users(:bob).id}"
    assert_select "#locker-wish-row-#{users(:henry).id}", false
  end

  # Same contract, the other side: an explicit *blank* value ("All floors",
  # chosen deliberately) is respected too, not treated as absent.
  test "an explicit blank current_floor is respected as All floors, not re-derived" do
    sign_in users(:bob) # wish floor "7"

    get locker_wishes_path(current_floor: "")

    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "All floors"
    assert_select "#locker-wish-row-#{users(:henry).id}"
  end

  # FR-006: a rejected declare must not change "Their floor" from whatever was
  # submitted — including a value the viewer had set manually, different from
  # their (still unsaved) floor.
  test "a rejected declare leaves the submitted current_floor unchanged" do
    sign_in users(:dave)

    post locker_wish_path, params: { locker_wish: { floor: "" }, current_floor: "3" }

    assert_response :unprocessable_entity
    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "3"
  end

  # FR-012: the derivation reads only the signed-in viewer's own wish, never
  # anyone else's — proven by two viewers whose wishes point at different
  # floors.
  test "the derivation is scoped to the viewer's own wish, not anyone else's" do
    sign_in users(:carol) # wish floor "5" — bob's is "7", a different active wish

    get locker_wishes_path

    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "5"
    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "7", count: 0
  end

  # Principle IV: deriving "Their floor" from the viewer's own wish reads an
  # association the controller already loads (`own_locker_wish`), so it must
  # not cost a query beyond what an unfiltered request already issues.
  test "deriving current_floor from an active wish costs no extra queries" do
    sign_in users(:dave)
    without_wish = count_queries { get locker_wishes_path }

    sign_out users(:dave)
    sign_in users(:bob)
    with_wish = count_queries { get locker_wishes_path }

    assert_operator with_wish, :<=, without_wish,
      "deriving current_floor issued #{with_wish} queries against #{without_wish} without a wish"
  end

  # FR-004: cancelling drops current_floor from the redirect target entirely,
  # rather than carrying forward whatever was submitted.
  test "cancelling drops current_floor from the redirect, regardless of what was submitted" do
    sign_in users(:bob) # wish floor "7"

    delete locker_wish_path, params: { current_floor: "5" }

    assert_redirected_to locker_wishes_path
  end

  # The redirect alone isn't the whole story: the *next* render must actually
  # land on "All floors" too, now that there is no wish left to derive from.
  test "a fresh request after cancelling shows All floors, having no wish left" do
    sign_in users(:bob) # wish floor "7"
    delete locker_wish_path

    get locker_wishes_path

    assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "All floors"
  end

  # Cancelling with current_floor already blank is a no-op on that axis, not
  # an error.
  test "cancelling with current_floor already blank redirects the same way" do
    sign_in users(:bob)

    delete locker_wish_path, params: { current_floor: "" }

    assert_redirected_to locker_wishes_path
  end

  # FR-019: "looking for floor" survives the viewer's own save, unchanged from
  # 017. "Their floor" does not survive it — 019 FR-003 overwrites whatever was
  # submitted with the newly declared floor, which is the whole point of this
  # feature. Rewritten from its 017 form on purpose (research R3): that version
  # asserted `current_floor: "2"` — the value submitted — survived the redirect
  # unchanged; it now asserts `current_floor: "4"` — the declared floor — does.
  test "declaring a wish returns to the list still filtered, its own floor overriding Their Floor" do
    sign_in users(:dave)

    post locker_wish_path, params: { locker_wish: { floor: "4" }, looking_for: "3", current_floor: "2" }

    assert_redirected_to locker_wishes_path(looking_for: "3", current_floor: "4")
  end

  # ...and their cancel.
  test "cancelling a wish returns to the list still filtered" do
    sign_in users(:bob)

    delete locker_wish_path, params: { looking_for: "3" }

    assert_redirected_to locker_wishes_path(looking_for: "3")
  end

  # FR-018/FR-007: "looking for floor" redirects to the bare path it always did
  # when nobody touched it, rather than to one carrying an empty parameter.
  # "Their floor" is the one exception (019): every successful declare now sets
  # it explicitly, so the redirect is never fully bare once a wish is declared.
  # Rewritten from its 017 form on purpose (research R3): that version asserted
  # the redirect carried no parameters at all.
  test "declaring with no filter in force redirects carrying only the declared floor" do
    sign_in users(:dave)

    post locker_wish_path, params: { locker_wish: { floor: "4" } }

    assert_redirected_to locker_wishes_path(current_floor: "4")
  end

  # Spec Edge Cases: a rejected declare comes back filtered exactly as it was,
  # rather than quietly widening the list underneath the error.
  test "a rejected declare re-renders the list still filtered" do
    sign_in users(:dave)

    post locker_wish_path, params: { locker_wish: { floor: "" }, looking_for: "3" }

    assert_response :unprocessable_entity
    assert_select "#locker-wish-row-#{users(:karl).id}"
    assert_select "#locker-wish-row-#{users(:bob).id}", false
  end

  # Principle IV: the evidence that filtering costs nothing per row. The two
  # DISTINCT choice queries are constant, so a filtered view — which reads fewer
  # rows — must not issue more queries than an unfiltered one.
  test "filtering issues no more queries than not filtering" do
    sign_in users(:dave)

    unfiltered = count_queries { get locker_wishes_path }
    filtered = count_queries { get locker_wishes_path(looking_for: "3", current_floor: "3") }

    assert_operator filtered, :<=, unfiltered,
      "filtering issued #{filtered} queries against #{unfiltered} unfiltered"
  end

  # --- 018: the reciprocal-match tag ------------------------------------------
  #
  # bob (floor "3", wish "7") reciprocates exactly with both henry and iris
  # (floor "7", wish "3" each) — see test/fixtures/users.yml and
  # test/fixtures/locker_wishes.yml.

  # 019: bob's own wish (floor "7") would otherwise auto-fill "Their floor" and
  # narrow the list to henry/iris alone, making the "and nowhere else" rows
  # below pass vacuously (absent, not merely untagged) rather than actually
  # proving anything. Pinned to "All floors" so every row this test names is
  # still on screen to be checked.
  test "the tag appears on every row that reciprocates with the viewer, and nowhere else" do
    sign_in users(:bob)

    get locker_wishes_path(current_floor: "")

    assert_select "#locker-wish-row-#{users(:henry).id}-swap span.badge-success", text: "It's a match!"
    assert_select "#locker-wish-row-#{users(:iris).id}-swap span.badge-success", text: "It's a match!"
    assert_select "#locker-wish-row-#{users(:carol).id}-swap span.badge-success", count: 0
    assert_select "#locker-wish-row-#{users(:judy).id}-swap span.badge-success", count: 0
    assert_select "#locker-wish-row-#{users(:karl).id}-swap span.badge-success", count: 0
  end

  # FR-003: no wish of the viewer's own means nothing to reciprocate, whatever
  # any row's floors are.
  test "no row carries the tag when the viewer has not declared a wish" do
    sign_in users(:dave)

    get locker_wishes_path

    assert_select "span.badge-success", count: 0
  end

  # FR-004: karl has a wish but no saved floor of his own.
  test "no row carries the tag when the viewer's own current floor is not recorded" do
    sign_in users(:karl)

    get locker_wishes_path

    assert_select "span.badge-success", count: 0
  end

  # FR-006 / spec Edge Cases: bob's own row would satisfy the formula once his
  # wish floor is set to match his own current floor exactly (the "mirror" case),
  # yet it must never carry the tag — the exclusion is unconditional.
  test "the viewer's own row never carries the tag, even if it would otherwise qualify" do
    sign_in users(:bob)
    users(:bob).locker_wish.update!(floor: users(:bob).saved_floor)

    get locker_wishes_path

    assert_select "#locker-wish-row-#{users(:bob).id}-swap span.badge-success", count: 0
  end

  # FR-008: a floor filter narrows which rows are reached, not how a reached row
  # is evaluated.
  test "the tag survives narrowing by a floor filter" do
    sign_in users(:bob)

    get locker_wishes_path(looking_for: "3")

    assert_select "#locker-wish-row-#{users(:henry).id}-swap span.badge-success", text: "It's a match!"
    assert_select "#locker-wish-row-#{users(:iris).id}-swap span.badge-success", text: "It's a match!"
  end

  # Principle IV / contract "Query-budget contract": the two extra reads this
  # feature introduces are attribute reads on associations already loaded, so
  # the query count must not depend on whether any row actually matches.
  #
  # Two separate, freshly-signed-in viewers rather than one viewer across two
  # requests: reusing a session for a second request in the same test carries an
  # unrelated extra Warden/session lookup that has nothing to do with this
  # feature and would make the comparison noisy.
  #
  # 019: current_floor is pinned to "" (All floors) explicitly for both viewers.
  # Left to auto-derive, bob's and carol's wishes point at different floors with
  # different numbers of current occupants — one filtered result empty, the
  # other not — which costs a different number of queries for a reason this
  # test has nothing to do with (the pre-existing `@locker_wishes.any?` then
  # `.each` evaluation taking a different path for an empty relation). Pinning
  # both to unfiltered isolates the one thing 018 is actually asserting here.
  test "rendering the list issues the same number of queries whether or not a match is present" do
    # 025: SiteLanguageSetting.current (read on every request, ApplicationController's
    # around_action) costs a SELECT+INSERT the first time it is ever called and a
    # plain SELECT thereafter — an asymmetry orthogonal to what this test measures.
    # Pre-warming it here means both requests below see an existing row and pay
    # the same, smaller cost, isolating the one thing 018 is actually asserting.
    SiteLanguageSetting.current

    sign_in users(:bob) # reciprocates with henry and iris
    with_matches = count_queries { get locker_wishes_path(current_floor: "") }

    sign_out users(:bob)
    sign_in users(:carol) # floor "2", wish "5" — nobody reciprocates
    without_matches = count_queries { get locker_wishes_path(current_floor: "") }

    assert_equal with_matches, without_matches
  end

  # FR-009 / spec Edge Cases: the tag is recomputed fresh on every render, never
  # remembered from a previous one.
  test "cancelling the viewer's own wish removes the tag on the next render" do
    sign_in users(:bob)
    get locker_wishes_path
    assert_select "#locker-wish-row-#{users(:henry).id}-swap span.badge-success"

    delete locker_wish_path
    get locker_wishes_path

    assert_select "span.badge-success", count: 0
  end

  private

    # What each axis offers, in the order it offers it — so a comparison catches a
    # choice appearing, vanishing or moving.
    def filter_choices_offered
      %w[locker-wish-filter-looking-for locker-wish-filter-current-floor].index_with do |group|
        css_select("##{group} a").map(&:text)
      end
    end

    def count_queries(&request)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &request)

      count
    end

    # No mocking gem is bundled (see Gemfile), so the stub is hand-rolled. It plays
    # the request that won the race: by the time the loser's write is rejected, the
    # row really does exist, which is what the rescue path then has to find. Only
    # the first save loses, so the rescue's own update can still go through.
    def with_the_first_save_losing_the_race(to:)
      race_already_lost = false

      LockerWish.class_eval do
        alias_method :save_without_forced_conflict, :save

        define_method(:save) do |**options|
          next save_without_forced_conflict(**options) if race_already_lost

          race_already_lost = true
          LockerWish.insert_all!([
            { user_id: to.id, floor: "99", created_at: Time.current, updated_at: Time.current }
          ])
          raise ActiveRecord::RecordNotUnique, "forced by test"
        end
      end

      yield
    ensure
      LockerWish.class_eval do
        remove_method :save
        alias_method :save, :save_without_forced_conflict
        remove_method :save_without_forced_conflict
      end
    end
end
