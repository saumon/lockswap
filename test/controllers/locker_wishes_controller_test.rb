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

    assert_redirected_to locker_wishes_path
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

    assert_redirected_to locker_wishes_path
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

  # FR-019: the filters survive the viewer's own save...
  test "declaring a wish returns to the list still filtered" do
    sign_in users(:dave)

    post locker_wish_path, params: { locker_wish: { floor: "4" }, looking_for: "3", current_floor: "2" }

    assert_redirected_to locker_wishes_path(looking_for: "3", current_floor: "2")
  end

  # ...and their cancel.
  test "cancelling a wish returns to the list still filtered" do
    sign_in users(:bob)

    delete locker_wish_path, params: { looking_for: "3" }

    assert_redirected_to locker_wishes_path(looking_for: "3")
  end

  # FR-018: an unfiltered view redirects to the bare path it always did, rather
  # than to one carrying two empty parameters.
  test "declaring with no filter in force redirects to the bare list" do
    sign_in users(:dave)

    post locker_wish_path, params: { locker_wish: { floor: "4" } }

    assert_redirected_to locker_wishes_path
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
