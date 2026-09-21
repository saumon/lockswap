# Phase 0 research: 026 — open the locker search on arrival from the homepage

Everything below was checked against the tree at `39700bd`, not recalled. Where a
claim is about a library, the line in the vendored asset that supports it is
quoted.

---

## R1 — How does a one-arrival, address-invisible intention travel?

**Decision.** A new `GET /locker_wish/new` action that sets an ordinary Rails
flash entry and immediately redirects to `locker_wishes_path`. The homepage's two
invitations point at that address instead of at the list.

**Rationale.** The spec's two hard constraints (FR-002 spent by one arrival,
FR-003 address unchanged) are exactly the contract Rails' flash already
implements: written before a redirect, readable by precisely one subsequent
request, swept automatically after it. The redirect is what satisfies FR-003 —
the address the person ends on, and can copy, bookmark or share, is the same
`/locker_wishes` the menu produces. Nothing new has to be invented, and nothing
has to be cleaned up.

The three properties the spec asks for fall out rather than being arranged:

| Spec | Why it holds |
|---|---|
| FR-002, reload lands folded | The flash was swept by the render that consumed it. A reload is a fresh request with no flash. |
| FR-002, Back/Forward land folded | `index.html.erb` already carries `<meta name="turbo-cache-control" content="no-cache">` (017 FR-018), so a restoration visit re-asks the server rather than replaying a snapshot. The server has no flash. |
| FR-003, address unchanged | The 302's target is the bare `locker_wishes_path`. Turbo Drive pushes the final URL, so history holds the canonical address and Back from it returns to the homepage. |

**Alternatives considered.**

- *Query parameter (`/locker_wishes?declare=1`)* — rejected outright by FR-003.
  It is the address, so it bookmarks, shares and replays on reload. This is the
  option the specify pass had assumed and the clarify pass reversed.
- *URL fragment (`#declare`)* — same defect, plus a fragment is not sent to the
  server, so the `<details open>` would have to be set by script after render.
- *Render `index` directly from `/locker_wish/new` with no redirect* — saves the
  round trip, but leaves the person on `/locker_wish/new`, an address that is
  distinguishable from the menu's and that re-opens on reload. Fails FR-002 and
  FR-003 together.
- *`sessionStorage` written by a click handler on the homepage, read and cleared
  by a Stimulus controller on the wish page* — genuinely one-shot and genuinely
  invisible in the address, and it avoids the extra request. Rejected on three
  counts: it needs JavaScript for a disclosure that was deliberately built
  without any (`_locker_wish_panel.html.erb` opens with "`<details>` gives that
  disclosure keyboard and screen reader support without any JavaScript of its
  own"); it can only be tested through the browser, where this suite is at its
  slowest and least reliable; and it puts the open/closed decision on the client,
  after render, where the `<details>` would visibly snap open a frame late.
- *`request.referer` sniffing* — rejected. Referrers are suppressed by privacy
  settings and by some link rels, so the feature would work for some people and
  not others with nothing on screen to explain the difference. It also cannot
  distinguish the two invitations from any other homepage link.

**Cost, stated plainly.** One extra HTTP round trip on this navigation. It is a
human-initiated page change, not a hot path; the redirect action itself runs no
query beyond the `authenticate_user!` session load. See R7.

---

## R2 — Will a custom flash key render as a toast?

**Decision.** No, and no guard is needed. `app/views/layouts/_flash.html.erb`
does not iterate the flash hash — it builds its list from exactly two helpers:

```erb
notifications = [
  [ notice, "status", "toast-success" ],
  [ alert,  "alert",  "toast-error" ]
].select { |message, _role, _palette| message.present? }
```

A key that is neither `:notice` nor `:alert` is invisible to the toast layer.
`flash[:open_wish_form] = true` therefore carries the intention without putting
anything on screen, which is what FR-012 ("reaching the screen with the intention
MUST NOT create, modify or withdraw a locker search") and the spec's silence
about any arrival message both require.

**Consequence for the implementation.** The key must *not* be added to
`add_flash_types`. That helper exists to let `redirect_to` take the key as an
option, and its only effect here would be to invite someone later to render it.

---

## R3 — How is focus placed, and does it survive Turbo?

**Decision.** The HTML `autofocus` attribute on the floor field, rendered by the
server on the same response that renders `<details open>`. No JavaScript.

**Verified, not assumed.** turbo-rails 2.0.23
(`/usr/local/rvm/gems/ruby-3.4.6/gems/turbo-rails-2.0.23/app/assets/javascripts/turbo.min.js`):

1. `PageRenderer#finishRendering` calls it on every real render:

   ```js
   finishRendering() {
     super.finishRendering();
     if (!this.isPreview) {
       this.focusFirstAutofocusableElement();
     }
   }
   ```

2. The element it picks is filtered:

   ```js
   function E(e){return!!e&&null==e.closest("[inert], :disabled, [hidden], details:not([open]), dialog:not([open])")&&"function"==typeof e.focus}
   function A(e){return Array.from(e.querySelectorAll("[autofocus]")).find(E)}
   ```

   **`details:not([open])` is in that exclusion list.** This is the load-bearing
   detail of the whole design: the `open` attribute and the `autofocus` attribute
   must arrive in the *same server response*. Open the disclosure with script
   after render and Turbo will already have skipped the field; render `autofocus`
   into a closed `<details>` and nothing is focused, silently. Native browser
   autofocus on a cold load behaves the same way, so the two paths agree.

3. `shouldAutofocus` returns `true` on the base renderer and `false` only on
   `MorphingPageRenderer`. This app does not opt into morphing — no
   `turbo-refresh-method` meta anywhere in `app/views` — so the morph path is not
   reachable here.

4. `isPreview` is never true for this screen: it declares
   `turbo-cache-control: no-cache`, so there is no cached snapshot to preview.

**No collision.** `grep -rn autofocus app/` finds exactly one other use, on the
account-edit e-mail field (`devise/registrations/edit.html.erb`). Nothing on the
locker wishes screen competes for the first-autofocusable slot.

---

## R4 — Does focus land clear of the sticky header (FR-014)?

**Decision.** Nothing to build. `app/assets/tailwind/application.css:348` already
declares

```css
scroll-padding-top: calc(var(--size-bar) + var(--spacing-4));
```

on `html`, which is CLAUDE.md's coupling #2 — "clears it so anything the keyboard
scrolls into view doesn't land behind the glass". Browser focus scrolling honours
`scroll-padding-top`, so a focused field is scrolled to below the frosted bar by
the rule that is already there.

In practice the panel sits directly under the page title, so on a desktop
viewport the field is usually in view and no scroll happens at all. The rule
matters on the phone treatment and when the wish list is long enough to have
carried the viewport down. FR-014's second half — "MUST NOT depend on an
animation having run" — is satisfied by construction: `autofocus` is applied at
render time by the browser or by `finishRendering`, neither of which waits on the
entrance animation. The entrance animates `opacity` and `transform` only, so it
cannot move the field's layout box out from under the focus scroll.

---

## R5 — What happens across sign-in?

**Finding, no decision needed.** The invitations are only rendered to a signed-in
person, so the ordinary path never meets this. But `/locker_wish/new` is a GET
that an anonymous visitor can type, and `LockerWishesController` already carries
`before_action :authenticate_user!`, so Devise's failure app stores the attempted
location and returns to it after sign-in — at which point `#new` runs, sets the
flash and redirects with the zone open.

The spec explicitly permits either outcome ("an intention that does not survive
the trip through sign-in simply yields the ordinary folded screen"), so surviving
is a bonus rather than a requirement. It is worth a test all the same, because it
is the one path where an unauthenticated request touches the new action, and
`test/system/access_control_test.rb` is where this codebase records that kind of
fact.

---

## R6 — Which viewer sees which panel, and where the guard belongs

**Finding.** Both homepage invitations are rendered only in the two branches of
`home/_locker_wish.html.erb` where `current_user.locker_wish` is absent. On
arrival, `_locker_wish_panel.html.erb` therefore takes its `else` branch — the
one whose summary is `looking_for_a_locker` ("I'm looking for a locker" /
"Je recherche un casier"). One behaviour covers both buttons, as the spec assumed.

**Decision on where FR-008 is enforced.** The controller exposes only the raw
fact — *this arrival asked for the declare form* — and the view decides where
that fact applies, by using it solely inside the `else` branch. The persisted
branch's nested "Change floor" disclosure keeps its existing `errors.any?`
condition untouched.

This is deliberately *not* a `persisted?` check in the controller as well. That
would be the same rule written twice, which CLAUDE.md calls a defect ("One
definition per component"), and the branch structure is the stronger guarantee of
the two: the zone FR-008 protects is in a branch that does not render at all for
a viewer who has a wish.

**Consequence for the shared form partial.** `_locker_wish_form.html.erb` is
rendered from both branches, so `autofocus` is passed in as a local rather than
read from an instance variable — the declare call site passes the flag, the
"Change floor" call site passes `false`. Declaring it with Rails 8 strict locals
(`<%# locals: (autofocus: false) %>`) documents the partial's interface at the
partial, which Principle I asks for and which a bare `local_assigns` lookup would
leave implicit.

---

## R7 — Performance (Principle IV)

**Decision.** No benchmark required, and none invented.

- The index render gains one instance-variable read from the flash. It issues no
  query. The existing query-count assertions in
  `test/controllers/locker_wishes_controller_test.rb` — "filtering issues no more
  queries than not filtering", "deriving current_floor from an active wish costs
  no extra queries", "rendering the list issues the same number of queries
  whether or not a match is present" — are the measurement, and they must still
  pass unchanged. That is the before/after evidence Principle IV asks for.
- The new `#new` action runs `authenticate_user!` and redirects. It renders no
  view and touches no locker data.
- The extra round trip is on a user-initiated navigation between two pages, not
  on the swap/lock execution path the principle is aimed at.

---

## R8 — Test strategy, and one known hazard

**Decision.** Controller tests carry the rule; system tests carry the two
journeys and the accessibility evidence.

The rule is fully observable server-side — a redirect, a flash, and whether the
rendered `<details>` carries `open` — so most of Story 1 and all of Story 2 and
Story 3 can be asserted in `test/controllers/locker_wishes_controller_test.rb`,
where the suite is fast and deterministic. Only two things genuinely need a
browser: that focus actually lands in the field (FR-005), and that it does so at
phone width too (FR-015).

**The hazard, recorded because it already bit this codebase.** The header comment
in `test/system/homepage_locker_wish_test.rb` documents three deleted tests:

> All three did the same thing — click the block's one control and assert the
> address changed — and all three failed intermittently, on a clean tree,
> independently of any change to the block: the click registered and the
> navigation did not.

This feature's Story 1 is precisely "click the block's one control and assert
what the next page looks like", so it walks straight back into that flake.
Mitigations, in the order they should be applied:

1. Use fixtures whose homepage fits the viewport — `erin` (floor, no locker, no
   wish) and `dave` (floor and locker, no wish). The recorded failure mode was
   worst on a homepage that had grown past the viewport because a swap proposal
   was in progress; neither of these has one.
2. Call `wait_for_turbo` after `log_in_as` (it already does) and again after the
   click, before asserting. The helper exists for exactly this race.
3. Assert on the destination's content (`assert_selector "details[open]"`),
   not on `assert_current_path` — the address is by design the same one the menu
   produces, so the address says nothing about whether the feature worked.
4. Keep the number of click-through tests to the minimum that proves focus: two
   (one per invitation) at desktop, one at phone. Everything else that could be
   written as a click-through is already covered by a controller test.

CLAUDE.md's own note applies too: use fixture users, never freshly created ones,
or the menu toggle goes flaky in browser-driven captures.
