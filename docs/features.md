# Feature history

Feature-by-feature record of what LockSwap does, 001 → 034. The specs in [`specs/`](../specs/) are the source of truth; this page is the narrative.

The project started with the foundations — without user accounts, no locker swap is possible — and
now carries the swap through end to end: declare what you are looking for, offer a swap, answer one,
and have facilities services validate it once the lockers have actually changed hands. The details being negotiated are held
still while that plays out, and the history says what each proposal was about without anyone having
had to write it down. Locker numbers are counted per floor, the way they are on the doors. What the
application says back — saved, sent, refused — shows itself for a few seconds and then gets out of
the way. And it now looks like a product rather than a scaffold: a logo, a typeface, a white canvas
and a small amount of movement, applied the same way on every screen. The first thing a new account
is asked is a question with two answers rather than a form with an optional field in it, and the way
back into those details is a pencil in the corner of the card instead of a bar announcing itself
underneath it. And the homepage no longer keeps quiet about what someone is looking for: it says
which floor they are after, or asks them, in the words that fit what they already hold. The logo has
stopped standing still, too: on the way in, and in the corner of every page after it, the mark
breathes — slowly, by itself, and not at all for anyone who has asked their system for less movement.
And it now fits the screen it is actually being read on: the menu folds behind a single control on a
phone and stays a bar on a desktop, the swap lists stop being tables too wide to read and become one
labelled card per person, and nothing anywhere asks to be scrolled sideways. The site has also
acquired somebody in charge: whoever registered first, decided once and never handed on, with a menu
of their own holding the list of everyone who has signed up. And signing up no longer takes the
password on trust: it is typed twice and the two have to agree, with an eye on each field for anyone
who would rather read back what they typed than find out at the login form. Being in charge has
stopped being something one account holds alone, too: an administrator can hand the role to somebody
else from the list they already had, behind a confirmation that names the account and says the grant
cannot be taken back — and each row now says where its rights came from, so a site with several
administrators can still answer how each of them got there. And who may join at all has become
something the site can decide: an administrator can list the email domains allowed to register, and a
signup from anywhere else is refused. With that list left empty, which is where every instance starts,
registration stays open to everyone exactly as it was. And the list of everyone looking for a locker
has stopped being one long read: it narrows by the floor people are after, by the floor they hold
today, or by both at once — which is the shortlist of people a straight two-way swap would suit. The
address carries what is being filtered, so a narrowed view can be shared or come back to, and only the
list moves when it changes. And the list now points out the one swap guaranteed to work both ways: a
row is tagged **It's a match!** the moment its person is on the floor you want and wants the floor you
are on, computed fresh every time the list is shown rather than remembered from before. And declaring
what you are looking for now does more than record it: **Their floor**, the filter that answers who
already holds what you want, sets itself to that same floor the moment the wish is saved, moves with
it the moment it changes, and stands back down to *All floors* the moment it is cancelled — so seeing
who to approach costs one action instead of two. And the administrator's own list of who is registered
no longer stops at email and role: every row now says that account's current floor, current locker, and
whether they are looking for one — the same facts already shown on the homepage and the locker wishes
list, read off this one screen instead of two. Four filters sit above it, combinable and immediate: an
exact locker number, a floor, a role, or part of an email, narrowing a long list down to the handful of
accounts that actually matter, with a plain message when a combination matches nobody rather than a
screen that looks broken. And the product has stopped looking like a tasteful default: the logo's two
lockers — one blue, one green, changing places — are now the whole interface. Blue means what is
yours and green means somebody else's, on the leading edge of every card, on the rail of every row,
and on the buttons, which run the two colours as a gradient and reverse it under the pointer.
Everything measured — a floor, a locker number, an address, a date — is set in a monospaced face with
tabular figures, so a column of locker numbers lines up on the digit; everything written stays in the
brand's own face. The page sits on a faint grid rather than an empty white field, the page titles have
come out of their cards, and the header has become a strip of frosted glass that the content scrolls
underneath. All of it is written down, so the next change extends it instead of replacing it with
something else tasteful. And what counts as a floor, or as a locker number, has become the site's to
decide rather than whatever each person happens to type: the super admin lists the floors the building
actually has, and every floor field becomes a choice from that list — so "1", "01" and "1st" can no
longer be three different floors that never match — and can set the format a locker number must follow,
with examples on the same screen of what each pattern accepts and refuses. Until either is set, nothing
changes, and whatever is already on file stays as it is until it is next edited. And the site now
knows which lockers actually exist: an administrator draws the building's zones floor by floor on a
Locker Map and lists the locker numbers physically in each one, and from the first locker declared
onwards, a floor and locker number only save if the map recognises them — until then, nothing is
checked, exactly as before. Where a locker sits is no longer something to remember, either: its zone
appears everywhere its floor and number already do — your own locker card, the locker search list, a
proposal received, an exchange under way, and the admin screens — read fresh each time, and simply
absent for a locker nobody has mapped. And the last step of a
swap now belongs to the people who can actually carry it out: once both colleagues have agreed, the
exchange waits on facilities services — who re-associate the badges in their own system — and an
administrator validates it, or refuses it with a reason, from a queue of their own. Neither colleague
can close it themselves any more; both are told plainly who it rests with. And an account now has to
prove it owns its address: signing up sends an activation link, and nobody signs in before following
it. A forgotten password is no longer the end of an account either — the sign-in page offers a reset
by email — and a changed address only takes effect once it has been confirmed from the new mailbox.
Whoever was already registered carries on exactly as before; for anyone whose email never arrives,
an administrator can activate the account by hand. How the site sends its mail, and how to point it
at your own SMTP server, has [a section of its own](email.md).

| Feature | Status |
| --- | --- |
| **001 — Signup and login** | ✅ Shipped |
| **002 — Floor and locker details** | ✅ Shipped |
| **003 — Locker search wish** | ✅ Shipped |
| **004 — Locker swap proposals** | ✅ Shipped |
| **005 — Locker field lock and swap history** | ✅ Shipped |
| **006 — Per-floor locker numbers** | ✅ Shipped |
| **007 — Self-dismissing notifications** | ✅ Shipped |
| **008 — Visual identity and white theme** | ✅ Shipped |
| **009 — First-entry choice and pencil edit** | ✅ Shipped |
| **010 — Homepage locker wish block** | ✅ Shipped |
| **011 — Looping logo fade** | ✅ Shipped |
| **012 — Responsive layout and menu** | ✅ Shipped |
| **013 — Admin role and user directory** | ✅ Shipped |
| **014 — Password confirmation and visibility toggle** | ✅ Shipped |
| **015 — Granting administrator rights** | ✅ Shipped |
| **016 — Danger Zone: allowed email domains** | ✅ Shipped |
| **017 — Floor filters on the locker wishes list** | ✅ Shipped |
| **018 — "It's a match!" tag on locker wishes** | ✅ Shipped |
| **019 — "Their floor" pre-filled from your wish** | ✅ Shipped |
| **020 — Locker/floor/wish and filters on the admin users screen** | ✅ Shipped |
| **021 — Design system rebuilt around the swap axis** | ✅ Shipped |
| **022 — Compact floor/locker label alignment** | ✅ Shipped |
| **023 — Modernized toast notifications** | ✅ Shipped |
| **025 — Site language setting (French/English)** | ✅ Shipped |
| **026 — Open the locker search on arrival from the homepage** | ✅ Shipped |
| **027 — Admin user detail view** | ✅ Shipped |
| **028 — Admin rights controls on the user detail screen** | ✅ Shipped |
| **029 — Super admin role and exclusive Danger Zone access** | ✅ Shipped |
| **030 — Configurable floors and locker number format** | ✅ Shipped |
| **031 — Locker map (zones and known lockers)** | ✅ Shipped |
| **032 — Locker zone visibility across screens** | ✅ Shipped |
| **033 — Administrator validation of locker swaps** | ✅ Shipped |
| **034 — Email activation and password reset** | ✅ Shipped |
| Locker directory and availability | ⏳ To be specified |

What feature 001 covers today — see
[`specs/001-user-authentication/spec.md`](../specs/001-user-authentication/spec.md):

* account creation with an email and a password (8 characters minimum, one account per address) —
  **since 034** the new account must be activated from an emailed link before it can sign in, so
  signing up no longer signs you in;
* login that leads straight to the homepage, which is closed to visitors who are not logged in;
* a session that persists for 30 days, browser restarts included, until the user logs out;
* a generic failure message, identical whether the email is unknown or the password is wrong;
* the account is locked for 15 minutes after 5 consecutive failures.

What feature 002 adds — see
[`specs/002-locker-floor-profile/spec.md`](../specs/002-locker-floor-profile/spec.md):

* the floor and the locker number are shown on the homepage as soon as they are on file;
* a user who has filled in nothing yet is asked for them right there, as **two separate fields**;
* the floor is required; the locker number is not, because having no locker assigned is an ordinary
  state and is displayed as such, never as an error. Both are typed freely — until 030, below, lets the
  super admin turn the floor into a choice from a list and hold the locker number to a format;
* a locker number belongs to one account at a time — a clash is refused without ever revealing who
  holds it, and the database enforces that even when two people submit at the same moment (scoped to
  a single floor since 006, below);
* the details can be changed later, behind a control that keeps the form out of the way so the
  homepage reports a settled state instead of standing permanently open for editing — a labelled bar
  at the time, a **pencil** in the corner of the card since 009, below.

What feature 003 adds — see
[`specs/003-locker-search-wish/spec.md`](../specs/003-locker-search-wish/spec.md):

* a **I'm looking for a locker** button declares that you are looking for a locker, and asks which floor
  before recording anything;
* one wish per account — declaring again moves the existing wish to the new floor instead of adding a
  second, and the database enforces that even when two declarations land at the same moment;
* the floor is required (blank or whitespace is refused) and free-form, exactly as on the profile —
  **superseded by 030** once the super admin has saved a floor list: it is then a choice from that
  list, on the wish exactly as on the profile;
* having no locker assigned is no obstacle to declaring a wish, and already holding one is precisely
  the point of a swap — neither blocks anything;
* a **Locker wishes** page lists every active wish to any logged-in user: who is looking (by email),
  the floor they are after, and the floor and locker they hold today — or that they hold none, said
  plainly rather than as an error — so a worthwhile swap is obvious at a glance;
* a wish can be cancelled at any time, which takes it off that list for everyone.

What feature 004 adds — see
[`specs/004-locker-swap-proposal/spec.md`](../specs/004-locker-swap-proposal/spec.md):

* a **Propose swap** control on every row of the **Locker wishes** page offers a swap to the person
  looking for a locker there — the requester needs neither a locker nor a wish of their own;
* where a swap cannot be offered, the row says why instead of holding out a control that would only
  be refused: your own row, a proposal already pending with that person, or an exchange of your own
  already under way;
* the homepage is where proposals are answered, so none of them has to be hunted for — proposals
  **for you** (Accept, or Decline behind a disclosure with an optional comment), proposals **you
  sent** (Withdraw), the **exchange in progress**, and any decline that came back;
* a decline is shown **once**, with whatever the decliner said about it, and then lives on in the
  history rather than following the requester around forever;
* a proposal can be withdrawn right up until it is answered, and one answer is final — a proposal
  cannot be accepted or declined twice;
* accepting marks the exchange in progress **for both people** and automatically declines every other
  pending proposal either of them was part of, in either direction, telling each of those requesters
  why — nobody is left holding a proposal that can no longer go anywhere;
* nobody can be in two exchanges at once, and a wish stops being listed while its owner is mid-swap:
  the need is spoken for, so it is no longer an open invitation;
* **only the recipient who accepted** confirms that the swap actually happened; confirming swaps the
  floor and locker number between the two accounts and clears both wishes, the need now being settled.
  **Superseded by 033**: neither party confirms any more — an administrator validates the exchange,
  with exactly the same effect, or refuses it;
* a **Proposal history** page lists every proposal you sent or received — direction, the other person,
  the date, where it ended up, and any decline comment — read-only, because the homepage is where
  proposals are acted on and this is where they are looked back at.

What feature 005 adds — see
[`specs/005-swap-lock-history-comment/spec.md`](../specs/005-swap-lock-history-comment/spec.md):

* your floor and locker number are **held still while a swap is outstanding** — from the moment a
  proposal is sent or received until it is declined, withdrawn, or completed — because a proposal is
  an offer made on those exact values, and neither side should be able to move them out from under
  the other halfway through;
* the edit control — the **pencil** since 009, below — gives way to a plain explanation of why it is
  not available, rather than vanishing without a word or waiting to refuse the change after it has
  been typed;
* only a value **already on file** is held: someone who has never recorded a floor or a locker number
  is still asked for one, since offering a swap requires neither — holding people to a value they
  never set would strand them behind their own proposal;
* the hold lifts by itself as soon as the proposal is settled; there is nothing to unlock by hand;
* every row of the **Proposal history** now says which lockers it was about, filled in by the
  application rather than by either party — what is being *proposed* while a proposal is live, or was
  proposed if it was declined or withdrawn, and what was actually *exchanged* once it is completed;
* that summary has a column of its own, beside the decline comment rather than in place of it: one
  says why a person answered as they did, the other what was on the table, and a row can carry both;
* what a settled proposal says is **recorded as it settles**, so that a later change to either
  person's locker never quietly rewrites the history of an exchange that already happened.

What feature 006 corrects — see
[`specs/006-locker-floor-uniqueness/spec.md`](../specs/006-locker-floor-uniqueness/spec.md):

* locker 001 on floor 1 and locker 001 on floor 2 are **two different lockers**, and two people can
  hold them at the same time — until now the application treated a number as if it named a locker on
  its own, and refused the second person a locker that was genuinely free;
* what has to be unique is the **pair**, floor and number together: a clash is still refused, still
  without ever naming who holds it, and the database still enforces it when two people submit at the
  same moment — but only when both of them name the same floor;
* the refusal says which scope it is talking about — the number is unavailable **on that floor** —
  because the same number one floor up may well be there for the taking;
* changing floor re-checks the pair against the floor you are moving **to**, not the one you are
  leaving, so a move is refused only when the locker is actually occupied where you are heading;
* a pair stops being held the moment its holder moves off it, and is immediately free for anyone
  else to claim — nothing has to be released by hand;
* a locker number is still never stored without a floor: until a floor is given there is nothing to
  scope the number to, so the floor stays required exactly as before.

What feature 007 changes — see
[`specs/007-toast-notifications/spec.md`](../specs/007-toast-notifications/spec.md). Two of the statements
below describe 007 as it shipped and **no longer describe the application**: feature 023 moved the
notification and modernized its finish. They are marked where they occur:

* the lines the application answers with — **Signed in successfully.**, **Locker details saved.**, and
  every other one — used to be a block of text wedged at the top of the page that stayed there until
  something else replaced it; they now arrive as a **notification that takes itself away after three
  seconds**;
* nothing moves when one comes or goes: the message floats at the top right, below the header,
  instead of taking a strip out of the page — so the content underneath neither jumps down on arrival
  nor springs back on departure, the navigation stays visible and clickable throughout, and on a wide
  screen the message sits over the empty margin beside the content rather than over the content
  itself. **Superseded by 023**: the message now sits fixed at the bottom right of the screen instead,
  at every width, which is also what let it stop depending on the header's own published height;
* **the countdown stops while the pointer is resting on a message, or while the keyboard has landed
  on it**, and picks up where it left off once you move away — three seconds is not long enough for
  every reader, and a message that vanishes mid-sentence cannot be asked for a second time;
* a reader who is already done can dismiss one by hand rather than waiting the rest of the countdown
  out;
* a success still reads as a success and a refusal as a refusal, at a glance and without reading the
  words — and each keeps the role that has a screen reader announce it, politely for a confirmation
  and insistently for a failure. **Superseded by 023**: color is no longer the only visual signal —
  each message now carries a type icon as well, so the two are told apart even by a reader who cannot
  perceive color;
* two messages on the same page stack rather than one quietly standing in for the other, and a long
  one wraps and grows downwards instead of spilling out of the window.

What feature 008 brings — see
[`specs/008-visual-identity-refresh/spec.md`](../specs/008-visual-identity-refresh/spec.md):

* the application has a **logo**: two lockers changing places, with arrows circling them. The sign-in
  and sign-up screens show the supplied artwork as an image, downscaled but otherwise untouched, at
  more than twice the size it is ever drawn at so it stays crisp on any display; the master it came
  from is kept alongside it in `brand/`. Everywhere the mark has to be small or animated — the header
  of every signed-in page, the browser tab, the installed-app icon, where it replaces the red circle
  Rails ships as a placeholder — it is a vector form of the same mark, traced from that artwork by
  colour rather than redrawn by eye;
* **the sign-in and sign-up screens have no menu bar.** They open on the logo instead, shown large
  with the wordmark and the tagline beneath it — a header there would have put the brand on the page
  twice and held nothing else, since every control in it belongs to someone already signed in;
* the **wordmark is real text, not a picture**: `Lock` in the brand navy and `Swap` in the brand
  green, set in the brand typeface. It stays selectable, it is read out properly by a screen reader,
  and if the drawing ever fails to load the name is still there and still links home;
* the **colours come from the artwork itself**, sampled rather than eyeballed, and are declared once
  as named tokens that every screen refers to — so there is one place to change a colour, and no
  screen can quietly drift away from the others;
* **the brand green is not used for text.** Against white it sits at 2.66:1, which is below the
  legibility floor for reading. It stays in the logo, where the accessibility standard exempts a
  brand name, and everything else that needs to be green — buttons, confirmations, saved states —
  uses a darker green chosen to pass comfortably. A logo may be a logo; a button has to be readable;
* the typeface is **served from this application, never from a font host**. A third-party font
  service sees the address of every visitor who loads a page, and that is not a thing to hand over
  for a typeface. One file, 39 kB, covers every weight the site uses;
* **every screen was restyled**, including the account-settings page, which until now was the
  unstyled scaffold Devise generates. Buttons, form fields, cards, badges, empty states and
  notifications each have one definition and are reused, in place of the same long string of styling
  copied from template to template;
* nothing was **added, removed or reworded**. Layouts were rearranged where that made a screen
  clearer; what is on each screen, and what you can do there, is exactly what it was. The one
  exception is the tagline on the sign-in and sign-up pages;
* there is **movement, and it is restrained**: content eases in as a page loads, controls answer the
  pointer and the keyboard, and a button says it is working while a form is in flight. There are no
  reveals that wait for you to scroll, and no animation between pages — both age badly, and the
  first can leave content invisible;
* on the sign-in and sign-up screens **the logo comes out of a fog**: it fades up from a blur over
  about a second, the mark first and then the wordmark and the tagline a beat behind it, so the brand
  assembles rather than landing all at once. That entrance plays once and settles sharp, and the mark
  in the header of the signed-in screens does not do it at all — a logo that fades up out of a blur on
  every navigation is a tic. (Both marks have gone on quietly breathing since 011, below — a separate
  animation that starts where this one stops, not a repeat of it);
* **anyone who has asked their system to reduce motion gets none of it**, with every screen still
  complete and fully usable. That is not an afterthought switch: it is asserted by the test suite;
* every screen is checked for **accessibility on every test run** — contrast, a visible focus ring on
  everything reachable by keyboard, names on every control, headings in order — so a regression fails
  the build rather than reaching a reader. The keyboard is also walked across the rearranged screens
  to confirm it still moves through them in the order the eye does;
* the refresh **cost nothing in speed**: the page paints at the same moment it did before, measured
  before and after, and the whole visual identity adds about 40 kB.

What feature 009 changes — see
[`specs/009-locker-entry-pencil-edit/spec.md`](../specs/009-locker-entry-pencil-edit/spec.md):

* the first screen a new account sees stops asking everyone for a locker number they may not have. It
  asks a question instead — fill in your floor and your locker, or say **I don't have a locker 😔** —
  and saying so takes the locker number field off the screen rather than leaving it standing there
  empty with a note explaining that it is optional;
* the answer can be taken back before anything is saved, and a floor typed before taking it back
  survives the switch in either direction: the floor is required whichever way the question is
  answered, and 009 removes the locker number from it, not the floor;
* a locker number typed and then disowned is **cleared, not merely hidden** — what gets saved says
  what the person said, instead of quietly recording a locker the account has just declared it does
  not have;
* the **Edit locker details** bar that used to sit under the locker card is now a **pencil in the
  card's corner**: the same control, the same form behind it, the same keyboard and screen-reader
  behaviour. It is the label that is gone, because the page was saying the word "edit" on every visit
  whether or not anyone was editing;
* the pencil still **says what it is** to a screen reader despite showing no text, and that name is
  asserted on every test run rather than assumed;
* the pencil opens the plain two-field form and never the first-entry question: an account with a
  floor on file has already answered it, and clearing the locker number there says the same thing.

What feature 010 adds — see
[`specs/010-homepage-locker-wish-block/spec.md`](../specs/010-homepage-locker-wish-block/spec.md). One of
the statements below describes 010 as it shipped and **no longer fully describes the application**:
feature 026 changed what the two invitation buttons hand off to. It is marked where it occurs:

* the homepage now says where your locker search stands, instead of leaving a declared wish to be
  remembered or looked up. It shows **the floor you are looking on**, and the way back to the page
  that can change or cancel it — **Review locker wishes! 🥷**;
* someone who has declared nothing is **asked, in the words that fit what they hold**: a locker
  holder is offered a swap — **I want to switch my locker! 👀** — and someone with no locker is
  asking for one — **I want a locker! 🙏**. Both are buttons, not remarks: the person with the least
  to trade is the last one who should be left without a way forward;
* exactly **one of the three** is ever on screen — never two, never none — and a declared wish
  outranks both invitations, so nobody who has already said what they want is asked again;
* the block **reports, it does not act**: declaring, moving and cancelling stay on the wishes page,
  which every state links to in a single click or keypress. **Superseded by 026**: for the two
  invitation buttons specifically, that one click now also opens the wishes page's search form and
  places the cursor in the Floor field — the click still only *links*, but the page it lands on is no
  longer folded shut behind a summary the person has to press a second time;
* it says **only the floor you are looking for**. What you hold today is on the card immediately
  below, and one fact in two places is one fact free to disagree with itself;
* it sits **after the proposals waiting on you** — those cannot move without an answer — and **above
  your locker details**, which are there to be read rather than acted on;
* a **new account never sees it**: the first screen asks one question, and a second card competing
  with it is exactly what 009 had just finished taking off that screen. It appears once the details
  are on file, whichever way they were answered;
* an **outstanding swap proposal changes nothing here**. It freezes the locker card below, because
  those values are what the other side agreed to — but a wish says what someone wants, which no
  proposal has a claim on.

What feature 011 changes — see
[`specs/011-logo-fade-loop/spec.md`](../specs/011-logo-fade-loop/spec.md):

* **the logo no longer goes still.** On the sign-in and sign-up screens it used to arrive out of its
  blur and then sit there for the rest of the visit; it now keeps **breathing** — fading down to 60%
  and back over about three seconds, for as long as the screen is up. A logo that moved once, before
  the reader had settled, was a logo nobody saw move;
* **the mark in the header does it too**, on every page, for as long as you are signed in. It starts
  breathing at first paint rather than waiting: there is no entrance in front of it to wait for, and
  008's reason for keeping the header still was about *that* entrance — a blur fading up on every
  navigation — not about movement as such;
* the two animations are **chained, never overlapped**. On the full-brand screens the pulse is held
  back by exactly as long as the entrance lasts, so its first frame lands on the frame the entrance
  has just finished holding. Both are at full opacity there, which is why the hand-off cannot be
  seen — and why the entrance is not left fighting the loop for the same property halfway through;
* **only the mark breathes, not the wordmark beside it.** In the header the artwork dims while
  `LockSwap` holds steady: a lock-up whose two halves faded in step would read as the logo coming
  apart rather than as one mark breathing;
* it **dims to 60% and no further**. Deep enough to be plainly noticeable — the point is to catch the
  eye — and shallow enough that the mark never looks like it is failing to load, or disappearing;
* nothing **moves, resizes or becomes harder to click**. The animation touches opacity and nothing
  else, so it stays off the layout entirely and rides the compositor rather than repainting — which
  matters for something that now runs on every page, including while the reader is scrolling. The
  header logo is a working link to the homepage at every point in the cycle, and the test suite
  measures the mark's box at the top and the bottom of a pulse to prove it has not budged;
* **anyone who has asked their system to reduce motion gets none of it**, on either screen. Not a
  flattened version of it: the rule is not declared for them at all, so the mark is simply painted,
  still and fully opaque, on the first frame — a loop that relied on being interrupted to reach its
  resting state is a loop that can leave a logo stranded half-faded.

What feature 012 changes — see
[`specs/012-responsive-layout-menu/spec.md`](../specs/012-responsive-layout-menu/spec.md):

* **the site now fits the screen it is being read on**, from 320 px upward, with nothing anywhere
  asking to be scrolled sideways. One breakpoint at **48 rem (768 px)** decides everything — the
  menu, the lists, the size of a control — and the stylesheet is not allowed a second one: a unit
  test reads the file and fails on any media query at another width. Two breakpoints is how a site
  ends up in one treatment here and the other one there;
* **the menu folds behind a single control below that line** and stays the bar it has always been
  above it. Nothing is taken away: the two destinations, your address and the way out are all still
  there, one tap further in. 768 px was chosen over the narrower, more usual 640 px because the swap
  history has six columns — it needs the extra width to be a table at all;
* it is built on the browser's own disclosure, the same one the locker editor and the wish panel
  already use, so **opening it, closing it, moving through it by keyboard and announcing whether it
  is open all happen without a line of JavaScript**. Script adds Escape and tapping outside to
  dismiss it; if it never loads, the menu still opens and closes and no destination is lost;
* the first attempt rendered **one** menu and took it apart with CSS on wide screens. It looked
  right — the bar laid out correctly and the browser reported the links visible — and it was wrong
  anyway: anything inside a *closed* disclosure counts as hidden to the platform whatever the
  stylesheet says, and the tooling that automates browsers says so outright. A bar whose links are
  visible only to someone reading pixels is not a bar. Each treatment now gets its own container and
  exactly one is ever present, both filled from **one partial**, so there is still a single answer to
  what the menu contains;
* **the two swap lists stop being tables on a phone** and become one card per person, every value
  labelled with the column it came from. The reason is the button: *Propose swap* is the last column
  of the widest table in the app, which on a phone put the primary action of the whole product
  off-screen behind a sideways swipe nobody discovers. The markup is unchanged — one table, rendered
  once — so both forms show the same people in the same order, because there is only one order;
* the header row is **hidden rather than removed** in that form, and each cell states its own role
  outright. Changing how an element is laid out quietly strips the meaning a table carries, and a
  screen reader has to still meet each record as a set of labelled fields rather than as loose text.
  The audit is what proves it, not the intention;
* **controls grow to a real thumb's worth of target below the breakpoint** — 44 px — and keep the
  tighter sizing 008 and 009 chose above it, so nothing on a desktop moved. Links sitting inside a
  sentence are left alone, because a 44 px-tall link in a paragraph wrecks the line it is in. This
  turned up a genuine defect on the way: the **dismiss cross on a notification was a 20 px target**,
  on a message that floats over the page — so a miss did not just fail, it pressed whatever was
  underneath;
* **the accessibility audit now runs at phone width too**, on every screen, including with the menu
  open — a state that only exists below the breakpoint and would otherwise never have been looked at.
  The keyboard is walked in both treatments, because restacking a layout is allowed and reordering it
  underneath someone navigating by Tab is not.

What feature 013 adds — see
[`specs/013-admin-user-directory/spec.md`](../specs/013-admin-user-directory/spec.md). Four of the
statements below describe 013 as it shipped and **no longer describe the application**: feature 015
lifted the one-administrator limit and gave the Users screen its first control, closing the case where
the site could be left with nobody in charge; features 027 and 028 then moved every capability that
acts on an account off the list and onto a detail screen of its own, and gave that screen a
counterpart for 015's control. They are marked where they occur:

* **the first account ever registered is the site's administrator**, decided at the moment it signs
  up and with nothing to configure. There is no setup step, no seed, no environment variable: the
  person who opens the application first is the person it belongs to;
* that answer is **written down rather than worked out**. The difference only shows when the
  administrator deletes their own account: an application that asked "who is oldest?" would quietly
  hand the role to whoever is now oldest, and this one hands it to nobody. The site is left without
  an administrator until somebody says otherwise, which is the honest outcome — the role was given to
  an account, not to a position in a queue. **Superseded by 015**: nobody is promoted automatically,
  still, but that outcome is no longer reachable — the last administrator's account cannot be
  cancelled while there is anyone left to administer;
* **one administrator, and the database is what promises it** — **Superseded by 015**, which lifted
  the limit without giving up the promise: the index was narrowed rather than dropped, so any number
  of accounts may be *granted* the role while exactly one can still *claim* it at signup, which is
  what the paragraph below is really about. The check reads the table before
  writing to it, so two people signing up in the same instant can both find it empty and both claim
  the role; a unique index refuses the second, and the application catches that refusal and lets the
  signup through without the role rather than failing it. Losing a race is not a reason to be told
  your account could not be created;
* the administrator gets an **Admin menu that nobody else has**, with **Users** inside it. It is the
  browser's own disclosure, the fourth place in the application to use it, so it opens, closes, takes
  the keyboard and announces whether it is open with no JavaScript at all — and it folds into the
  phone menu and the desktop bar alike, because both are still filled from the one partial 012 left;
* **the menu being absent is not the security.** It is never drawn for anyone else, but what actually
  refuses a non-administrator is the request handler, which turns away an address that was typed,
  bookmarked, or guessed and says plainly why rather than pretending the page does not exist. A link
  left out of a page has never stopped anyone typing a URL;
* **Users** lists **every account that has ever registered**, the administrator's own included,
  oldest first — which puts the administrator at the top without the ordering having to mention the
  role, since the account holding it is by definition the first one there was. Each row is an email
  address, the date it joined, and, on exactly one of them, a badge reading **Admin**: the label is
  said outright rather than left to be inferred from a position in a list. **Superseded by 015**: as
  many rows carry that badge as there are administrators, and each one now says how it got there;
* it **reports, and offers nothing to press**. No promote, no demote, no edit, no delete — not
  because those were left for later, but because there is no such capability behind them: the role is
  claimed once at signup and by nothing else. A control that looked like one would be a promise the
  application cannot keep. **Superseded by 015, 027 and 028, in that order**: 015 added the capability
  to promote and put a control for it directly on this list; 027 gave each row a link to a dedicated
  detail screen and moved editing and search-cancellation there, on the account's own behalf; 028 then
  moved 015's promote control off this list entirely and onto that same detail screen, adding its
  counterpart, revoke, beside it. The list itself reports once more — one link per row, nothing that
  changes an account — and every capability that acts on one now lives on the screen that link opens.
  Delete remains absent: no control here, or on the detail screen, removes an account outright;
* it is **a table on a desktop and one labelled card per account on a phone**, from the same markup
  rendered once, on the single breakpoint 012 established — a new screen joins those rules rather
  than arriving with its own. It is audited for accessibility like every other screen, at both
  widths, and so is the Admin menu with its submenu open: a state that exists on one account's pages
  and would otherwise never have been looked at.

What feature 014 adds — see
[`specs/014-confirmation-mot-de-passe/spec.md`](../specs/014-confirmation-mot-de-passe/spec.md):

* **the signup form asks for the password twice**, and will not create the account unless the two
  agree exactly — a blank second field included, since leaving it empty is a mismatch and not a
  question that simply went unanswered. A password typed into a field of dots is a password nobody
  proofreads, and the first time a typo in one announces itself would otherwise be at the login form,
  from the wrong side of it;
* the refusal **says which of the two password problems it is**: *Confirm password doesn't match the
  password above*, which is a different sentence from the one about eight characters. Rails builds an
  error message out of the field's name, so the field is named once and the label and the error are
  the same words — otherwise the form answers in language it never used. The account-settings page's
  own confirmation field picks up that name too: one field, called one thing, wherever it appears;
* **it says so before the form is submitted, but not while you are still typing.** Nothing is said
  during the first pass through the confirmation field — a mismatch reported against a half-typed
  value is a complaint about something the reader has not finished saying, and every password typed
  one character at a time begins by not matching. The check runs when the field is first left, and
  from then on keeps itself current on every keystroke in either field, so a correction clears the
  message where it stands, with no second visit to the field and no round trip;
* **that hint is not the rule.** The two values are compared again on the server, and that is what
  actually refuses the signup; the form is `novalidate` precisely so that every refusal comes from one
  place, and with the script missing the signup behaves exactly as it should, only more quietly. It is
  also why no new validation was written: Devise has compared these two fields all along, and most of
  014 is the work of putting the second one on the page;
* **each field carries its own eye**, revealing what was typed into that field and nothing else.
  Revealing the one you are checking should not put the other on screen for whoever else is in the
  room. There is no state shared between the two controls to get that wrong with — each field gets its
  own — so their independence is a fact of how they are built rather than something remembered;
* the eye **stays open while you keep typing**, since the point is to watch the keys land and that is
  no use if it re-masks after every one; and both fields **start masked again on the next visit**, so
  the reveal lasts the visit and no longer;
* the control **says what it does rather than showing it**. Its name changes between *Show password*
  and *Hide password*, and it deliberately carries no pressed state alongside that: a button announced
  as "Hide password, pressed" gives two answers at once and leaves the listener to work out which of
  them describes now. Which eye is drawn — open, or struck through — is read off the field's own type
  in CSS, so the icon cannot end up describing a state the field is not in;
* it is **reachable and operable from the keyboard alone**, and a real target under a thumb: the 44 px
  012 settled on, which it meets by standing as tall as the field it sits in. The screen goes through
  the same accessibility audit as every other one, at both widths, on every test run.

What feature 015 adds — see
[`specs/015-grant-admin-rights/spec.md`](../specs/015-grant-admin-rights/spec.md). Five of the statements
below describe 015 as it shipped and **no longer describe the application**: feature 028 relocated the
grant control and made a grant reversible; feature 027 gave the same screen an editing capability of
its own; and feature 029 named one account among the administrators — the super admin — gave it one
capability the others no longer share, and replaced the rule that kept the site from being left with
nobody in charge with a stronger one that applies to that account alone. They are marked where they
occur:

* **an administrator can hand the role to somebody else**, from a button on that account's row in
  the list they already had. Nothing happens on the press: a confirmation names the account and says
  the grant cannot be undone, and only validating it does anything. It is the same construction the
  *Cancel my account* button has always used — the site's one existing way of asking "are you sure?"
  — rather than a modal written for the occasion. **Superseded by 028**: the button is no longer on the
  list at all — it moved to the account's own detail screen (027) — and the confirmation no longer
  claims the grant cannot be undone, since a revoke control now sits right beside it there;
* **no password is asked for on the way through**, which is exactly why the confirmation has to say
  the grant is permanent. That dialog is the only thing between a pointer and an irreversible change,
  and a confirmation that only confirms would be leaning on the reader already knowing what it costs.
  Re-typing a password was considered and turned down for consistency: the closest thing the
  application already does — closing your own account, which is no less final — is guarded by a
  confirmation and nothing more. **Superseded by 028**: a grant is no longer irreversible, and neither
  its own confirmation nor revoke's asks for a password — the same "one plain confirmation, no
  credential" shape now guards both directions;
* **there can now be any number of administrators, and the database still promises the part worth
  promising.** The index that made a second administrator impossible was narrowed rather than
  dropped: it covers only accounts that hold the role *without* having been granted it. Two people
  signing up in the same instant still cannot both claim it, so the race 013 settled stays settled,
  while accounts that were granted the role fall outside the constraint entirely. The predicate is
  the moment the grant happened and deliberately not the identity of whoever made it — that second
  column empties when the granting account is deleted, and an index keyed on it would let a granted
  administrator drift into the slot reserved for the very first account and collide with it;
* **rights obtained by grant are the same rights.** The same badge, the same menu, the same screen,
  and the ability to grant the role onwards in turn. Nothing anywhere asks *how* the role was
  obtained, because everything asks only whether it is held — which is a property of how the checks
  were written, not a promise anyone has to keep remembering. **Superseded by 029** for one account
  only: the one that has held the role since the very first registration reads *Super Admin* rather
  than *Admin*, and is the only one the Danger Zone (016) still opens for — every account whose rights
  were granted keeps exactly what is described above;
* **each row says where its rights came from**: *First registration*, or *Granted by* somebody *on* a
  date. It is not a log. The role is granted at most once and never taken back, so its origin is a
  single fact about the account rather than a history of events to page through — and it **outlives
  the account that granted it**: when that person leaves, the row reads *Granted on* a date
  *(account removed)* rather than quietly going blank where a name used to be;
* **granting is the whole of what was added.** 013 named four things this screen would not do —
  promote, demote, edit, delete — and gave the same reason for all four: there was no capability
  behind any of them, and a control that looked like one would be a promise the application could not
  keep. Exactly one of the four has a capability behind it now, so exactly one of them got a control.
  The other three are still absent, and still for that reason rather than for lack of time.
  **Superseded by 027 and 028**: demote (028's revoke) and edit (027's floor/locker correction, on the
  account's own detail screen) both have capabilities behind them now too — only delete is still
  absent, and still for the original reason;
* **the last administrator cannot walk out.** Granting became the only way into the role and nothing
  takes it away, which left cancelling an account as the only way out of it — and the way out led
  somewhere with no way back, since the role is only ever claimed automatically on a site with no
  accounts at all. So the cancellation is refused while other accounts remain, and the person is told
  what to do about it rather than merely stopped. The one case it lets through is the sole account
  left on a site: there is nobody to lock out, and whoever registers next claims the role exactly as
  the first one did. **Superseded by 029**, which replaced "the last administrator" with one specific
  account — the one that has held the role since the very first registration. That one account still
  cannot walk out while anyone else remains, and still can once it is the last account left, exactly
  as described above; every administrator granted the role afterward may now leave at any time,
  however many other administrators remain, because that one account's own permanence already keeps
  somebody in charge;
* **the control says which account it acts on**, to a screen reader as well as to the eye. A column
  of buttons all reading *Grant admin rights* is a column of identical buttons, and leaves somebody
  who cannot see the row counting their way down it — so each one carries the account's address in
  its accessible name. The screen stays a table on a desktop and one labelled card per account on a
  phone, on the single breakpoint 012 established, and goes through the same accessibility audit as
  every other screen at both widths.

What feature 016 adds — see
[`specs/016-danger-zone-email-domains/spec.md`](../specs/016-danger-zone-email-domains/spec.md). One of
the statements below describes 016 as it shipped and **no longer describes the application**: feature
029 narrowed who may open the Danger Zone from every administrator to one. It is marked where it
occurs:

* **the site can decide who is allowed to sign up at all**, by email domain. A **Danger Zone** screen,
  in the Admin menu beside *Users*, holds the list of domains that may create an account — **superseded
  by 029**: beside *Users* only for the one administrator, the super admin, who may still open it — with
  `company.com` on it, `someone@company.com` registers exactly as before and everybody else is turned
  away with *Your email address domain is not allowed*. It is named for the class of setting rather
  than for this one — what belongs on that screen is anything whose blast radius is the whole site;
* **an empty list is the absence of a restriction, not a restriction of nothing.** Every existing
  instance starts there and nothing changes until somebody adds a domain, which means this feature is
  inert until it is deliberately switched on. There is no separate on/off switch to get out of step
  with the list: the presence of a domain *is* the restriction, and taking the last one off lifts it
  again. That escape hatch is the reason removal is a first-class capability rather than something to
  add later — a restriction with no way back is a way to lock yourself out of your own application;
* **subdomains are not included.** `company.com` admits `company.com` and nothing else;
  `mail.company.com` has to be listed in its own right. The comparison is exact rather than a test on
  how an address ends, which is what stops `evilcompany.com` being admitted by a domain it merely
  finishes the same way as;
* **the accounts already registered are never re-judged.** The check runs at the moment an account is
  created and at no other, so configuring a domain cannot strand the people already on the site: they
  sign in, reset their passwords and edit their details exactly as before. A rule applied backwards
  would leave a whole company one mistyped domain away from being locked out of its own application;
* **the entries are checked before they are stored.** A value that is not a domain is refused with an
  example of one rather than a restatement of the rule, a domain already on the list is refused as a
  duplicate, and casing and stray whitespace are normalised instead of being treated as differences —
  *Company.COM* and *company.com* are the same domain, and the site keeps one of them. A refused
  entry comes back on the screen it was typed on, with the existing list still underneath it;
* **removing a domain is guarded the way granting the role is**, by a confirmation naming it — and
  when it is the last one, saying what taking it off opens up. Reopening the site to every domain is a
  larger thing than deleting a row, and it should not have to be inferred from a table going empty;
* **the menu entry is not the security**, as it was not for 013. The link is never drawn for anyone
  else, but what actually refuses a non-administrator is the request handler — on the screen and on
  both of the addresses that change the list, typed, bookmarked or guessed. The refusal shows none of
  the configuration it is refusing access to;
* it is **a table on a desktop and one labelled card per domain on a phone**, on the single breakpoint
  012 established, and it is audited for accessibility in three states rather than one: empty,
  populated, and showing a refused entry. Each *Remove* control carries its domain in its accessible
  name, because a column of buttons all reading *Remove* leaves somebody who cannot see the row
  counting their way down it.

What feature 017 adds — see
[`specs/017-locker-wishes-floor-filter/spec.md`](../specs/017-locker-wishes-floor-filter/spec.md):

* **the wish list narrows by floor, on either of the two floors a row carries.** *Looking for floor*
  answers "who wants the floor I am on" — the people a swap with me could suit; *Their floor* answers
  "who is sitting on the floor I want". They are separate controls because they answer separate
  questions, and setting both leaves only the rows matching both: looking for the 3rd, currently on
  the 1st, which is the shortlist for a straight two-way exchange. Every axis can be left on *All
  floors*, which is where the screen opens;
* **each filter always offers every floor, whatever the other one is set to.** Choices that appeared
  and vanished as you filtered would make it impossible to learn where your floor sits in the list, so
  they are drawn from all the active wishes rather than from what is left after the other filter has
  run. The cost is that you can pick a combination nobody satisfies — which is an ordinary outcome,
  and gets a message in its own words rather than the *Nobody is looking for a locker right now* that
  means something else entirely;
* **the floors are offered in the order people count them, not the order a computer sorts them.**
  Floors are free text, as they have been since 002, so they sort as text unless something says
  otherwise — which puts 10 between 1 and 2 and reads as a bug. Numbers come first in numeric order,
  anything that is not a number follows alphabetically, and nothing is normalised on the way: `3` and
  `03` remain two distinct floors, listed next to each other in a settled order;
* **the choices are links, not a dropdown.** A `<select>` that filters as its value changes fires on
  every arrow key, so somebody reading down the options with a keyboard would re-filter the list
  repeatedly without having chosen anything — the WCAG *On Input* failure. A link is activated
  deliberately and never by being focused, so picking a floor is one action and moving between them is
  none;
* **only the list moves.** Changing a filter leaves the panel where you declare your own wish, and
  your place on the page, exactly where they were — so five floors can be tried one after another
  without scrolling back down to the list each time;
* **what you are filtering by is in the address.** A narrowed view can be bookmarked, shared or
  reached with Back and Forward, and it survives your own edits: saving or cancelling your own wish
  returns you to the list still narrowed the way you left it. If your row no longer matches, it simply
  leaves — the filters are not quietly cleared to keep it in sight. A floor typed into the address
  that matches nothing is an empty result you can see and undo, never an error and never a silent
  return to the full list;
* **nothing about the rows changed.** Same columns, same order — oldest declaration first — same
  people eligible to appear, and *Propose swap* behaves exactly as it did. The filter takes rows away
  and does nothing else. Each control is a named landmark of its own, carrying the same words the
  column headings already use, and the choice in force is announced rather than merely coloured.

What feature 018 adds — see
[`specs/018-wishes-match-tag/spec.md`](../specs/018-wishes-match-tag/spec.md):

* **a row is tagged "It's a match!" the moment it reciprocates with you.** Not "this person is on the
  floor I want" alone, and not "this person wants the floor I'm on" alone — both, at once. That is the
  one kind of swap guaranteed to be accepted from both sides, and until now nothing on the screen said
  which rows qualified;
* **the tag lives where the row's other status text already lives.** It appears in the same *Swap*
  column as *Proposal pending* or *This is you*, alongside whichever of those already applies rather
  than in place of it — one more member of a family the screen already had, not a new one;
* **nothing shows without something of yours to reciprocate.** No wish declared, or no current floor
  on file, and no row is tagged, however the floors happen to line up. A row whose person has never
  saved a floor can't be tagged either — "Not set" isn't a floor to match;
* **your own row is never tagged**, even in the edge case where your current floor and the one you
  want happen to be the same value;
* **it's computed fresh, never remembered.** Cancel or change either side of the pair and the tag is
  gone the next time the list is shown — there is nothing cached to go stale;
* **it survives the floor filters from 017 unchanged**, adds no query of its own, and reuses the
  badge the screen already uses for other statuses rather than a new visual language.

What feature 019 adds — see
[`specs/019-floor-filter-prefill/spec.md`](../specs/019-floor-filter-prefill/spec.md):

* **declaring what you are looking for narrows the list to match, in the same action.** The moment a
  wish is saved, *Their floor* — the filter that answers "who already holds what I want" — is set to
  that same floor, and *Everyone looking for a locker* is already narrowed to it; finding out who to
  approach used to mean declaring, then filtering by hand, and now costs one action instead of two;
* **it keeps tracking the wish, not just the moment it was declared.** Leaving the screen and coming
  back, or simply reloading it, shows the same narrowed list again with nothing pressed — for as long
  as the wish stays active, every fresh look at the screen re-derives the filter from it;
* **changing the wish moves the filter with it**, immediately, even over a floor picked by hand
  earlier in the same visit — the filter is allowed to disagree with you for a while, but never with
  the wish that is actually on file;
* **cancelling puts the filter back to *All floors*** at the same moment the wish itself is
  withdrawn, and it stays there on the next visit too, since there is nothing left to derive a floor
  from;
* **a floor chosen by hand still holds its ground for the rest of the visit** — through an unrelated
  click on the other filter, through Back and Forward — and is only given up by leaving and coming
  back, or by the wish itself changing. *Looking for floor*, the screen's other filter, is never
  touched by any of this;
* **the one case the address alone cannot decide**: a bookmarked or shared link that already names a
  floor for *Their floor* reads exactly like returning to a step earlier in the same visit — both are
  the same request — so reopening it while a wish is still active shows the wish's floor rather than
  the one the link named. Kept in the address the way every other selection is, with that one accepted
  trade-off.

What feature 020 adds — see
[`specs/020-admin-users-filters/spec.md`](../specs/020-admin-users-filters/spec.md). Two of the statements
below describe 020 as it shipped and **no longer describe the application**: feature 028 removed the
grant control this section describes from the list entirely. They are marked where they occur:

* **every row on the admin Users screen now says where that account stands**: current floor, current
  locker, and whether they are looking for one — the same three facts already shown on that person's
  own homepage and on the locker wishes list, so an administrator no longer has to leave this screen
  to answer "who holds what, and who wants what";
* **"Not set", "No locker assigned" and "Not looking for a locker" are three different states**, said
  plainly rather than left as blank cells — never having saved a floor is not the same as having no
  locker, and neither is an error;
* **four independent filters narrow the list**: current floor and role are chosen from a list of
  links, the same keyboard-safe control the locker wishes filters introduced in 017; current locker
  and email are typed, and the list updates shortly after typing stops — an exact match on the locker
  number, any part of the email. Any combination of the four narrows to accounts matching every one of
  them, not just one;
* **only the list moves.** The four filters live inside the same kind of Turbo Frame 017 introduced,
  so changing one replaces the rows in place — the filter bar itself, and the administrator's place on
  the page, stay where they were;
* **granting administrator rights from a filtered list leaves it filtered.** The existing grant
  control (015) redirects back to the same narrowed view rather than resetting it, so promoting one
  account from a shortlist does not mean rebuilding that shortlist by hand. **Superseded by 028**: the
  control this describes no longer lives on the list at all — see below;
* **a combination that matches nobody says so in its own words**, distinct from the screen simply
  being empty, with every chosen filter still visible so one of them can be relaxed without losing the
  others;
* **nothing about the existing screen changed.** Same email, same "Joined" date, same **Admin** badge,
  same grant control and its confirmation — the new columns and filters sit alongside all of it rather
  than in place of any of it. **Superseded by 028**: the grant control is gone from this screen
  entirely now, relocated to the account's own detail screen (027) — every other fact named here is
  still exactly as it was.

What feature 021 brings — this one has no spec of its own; it was a design pass, and the contract it
produced is written down in [`CLAUDE.md`](../CLAUDE.md):

* **the logo has become the interface.** The mark is two lockers, one blue and one green, changing
  places; those two colours now carry a fixed meaning everywhere and are never spent on decoration.
  Blue is what belongs to the reader — their locker, their wish, their own row in a list, a proposal
  they sent. Green is somebody else's — the pool of people looking, an offer made to them, a proposal
  received. Navy is neither, and red is destructive. Having seen one screen you can read the next one
  by colour before reading a word of it;
* **cards are hung on a hinge, not floated on a shadow.** Each card carries a 3px coloured edge down
  its leading side, taken from that axis, and no drop shadow at all. An identical soft grey shadow
  under every card is precisely what makes a page of cards read as one undifferentiated mass; a
  coloured edge says what the card is about before it is read. The data lists carry the same mark as a
  2px rail on each row — permanent where the row has a side, on hover where it does not;
* **there is one accent fill on the site**, at two sizes. The primary button, the action inside a
  table row and the filter choice in force used to be three different green objects; they are now the
  same one. It is the swap axis as a gradient, and both ends are lifted from the mark itself rather
  than picked to look like it: the blue is the top stop of the blue door's own gradient, the green is
  the green door's face;
* **that fill reverses under the pointer.** The gradient is declared blue → green → blue and drawn at
  twice the width of the control, so half of it shows at a time; hovering slides the window to the
  other half. The button does not brighten and does not move — the two colours change places. On a
  product about two people exchanging lockers, that is the only hover it should have;
* **two typefaces, two jobs.** Nunito, the logo's own face, carries everything *written*: headings,
  prose, labels. JetBrains Mono carries everything *measured*: floors, locker numbers, email
  addresses, dates, column headings, filter chips and buttons — with tabular figures, so a column of
  locker numbers lines up on the digit instead of drifting. Both are served from this application, one
  variable file each, on the same terms 008 set for the first one. No text is uppercased anywhere;
* **the header is frosted glass and the page scrolls underneath it.** White at 58% over a wide blur,
  sticky at the top, with a hairline running blue to green beneath it — the axis, stated once at the
  top of every screen. On a phone the menu opens as a full-width sheet of the same material rather
  than a rounded card floating inside a full-bleed bar;
* **the canvas is not blank.** A navy grid at 5%, at a 24px pitch — the locker bank the product is
  about — so the page has a floor rather than being a white void with cards in it;
* **page titles left their cards.** The most important line on each screen used to sit in the same
  white rounded box as everything under it. It now sits directly on the grid, carrying the axis as a
  gradient, because a page belongs to neither side — it is where the two meet;
* **it is denser, because it is a tool.** Card padding, table rows and corner radii all came down; the
  column is wider, to give the five- and seven-column tables room they were being squeezed out of. A
  20px corner is the single most generic thing a card can do;
* **the movement is staged, and it is bounded.** The page fades, its blocks rise in sequence 40ms
  apart, and each card's hinge is drawn downwards — so a screen reads as constructed rather than as a
  fade. The whole chain finishes in 400ms, which is the budget 008 set, and anyone who has asked their
  system for less motion still gets none of it;
* **every colour pair was computed, not eyeballed** — and where a claim could not be computed it was
  measured off the rendered pixels instead. Whether the header's own labels survive content sliding
  behind the glass, and whether the menu panel's blur was doing anything at all, were both settled by
  sampling the screenshot rather than by argument. The second found a real bug: a `backdrop-filter` on
  an ancestor silently stops a descendant's from seeing the page, so the panel had been declaring a
  blur and painting a flat tint;
* **one known exception, stated rather than buried.** The button label is white, and on this gradient
  white measures 2.95:1 at the blue end and 1.87:1 at the green, against a 4.5:1 bar. It was set white
  deliberately, over an ink label that measured 5.62:1 and 8.91:1 on the same fill. The automated audit
  does not catch it — no tool computes contrast over a gradient — so it is recorded in the stylesheet,
  in `CLAUDE.md`, and here, together with the two ways out of it. Nothing else on the site is below its
  bar;
* **two system test files were trimmed**, on request, for being flaky rather than wrong:
  `locker_wish_filter_test.rb` was removed entirely, and three "click the control and check the
  address changed" tests were removed from the homepage wish block's file. What those three asserted
  is still asserted one level lower — the control's presence, its target, and its uniqueness — and the
  suite went from 288 system tests to 255.

What feature 022 adds — see
[`specs/022-align-floor-widgets/spec.md`](../specs/022-align-floor-widgets/spec.md):

* **the floor sought reads as one sentence.** "Your locker search" used to put the floor number on a
  line of its own, under "Looking for a locker on floor"; the two now read together, on the homepage
  and on the dedicated locker wishes page alike;
* **"Your locker" is two compact lines on a phone, not four.** Floor and its number, then Locker
  number and its value (or "No locker assigned"), each now share one line below the breakpoint instead
  of stacking the label above the value — the existing side-by-side desktop layout is untouched;
* **"Your locker" left its card on the homepage, but kept its colour.** It reads as plain content on
  the canvas now, carrying a solid blue rail rather than a full card — the same inset the page title
  uses, coloured to say "yours" rather than the title's neutral gradient — while "Your locker search"
  right above it keeps its card exactly as before;
* **the edit pencil no longer sticks.** Its hover fill is now scoped to devices that actually hover;
  a tap has no pointer-leave to end it, so on a touchscreen the control used to stay filled in after
  being tapped open instead of settling back to transparent.

What feature 023 adds — see
[`specs/023-toast-redesign/spec.md`](../specs/023-toast-redesign/spec.md):

* the notification **left the header's shadow and anchored itself to the corner it now owns**: fixed
  to the bottom-right of the screen at every width, instead of floating below the header on a wide
  screen and wherever the header happened to land it on a narrow one;
* **a type is now told apart by more than colour** — an icon rides beside the message, so a success
  and a refusal read apart even to an eye that cannot use colour as the signal;
* the finish is **the app's own, not a treatment invented for this one component**: the same tokens,
  the same corners, the same type as the cards and buttons around it, replacing the plain white strip
  007 first shipped;
* **a burst of notifications stays legible.** More than a handful queued at once used to mean a wall of
  identical boxes; now only so many are ever shown together, and the rest reveal themselves as the
  visible ones clear, rather than crowding the corner;
* nothing that already worked stopped working: the three-second countdown, its pause on hover or
  keyboard focus, the manual dismiss, and the screen-reader announcement are all exactly as 007 left
  them — only the notification's shape, colour finish, and corner changed.

What feature 025 adds — this one is documented in full under
[🌐 Localization](development.md#localization) below rather than repeated here:

* the site gained a **second Danger Zone setting** beside the allowed email domains (016): which of
  **English** or **French** the whole site is shown in, one shared choice for every visitor rather
  than a personal preference;
* a fresh install **starts in English**, and switching the setting reaches every visitor — including
  one with a page already open — by their very next request, with nobody asked to sign out and back
  in;
* **only the words move.** Dates, times and numbers keep one fixed format regardless of which language
  is selected, and nothing a person typed — a name, an email address, a comment — is ever translated.

What feature 026 adds — see
[`specs/026-locker-wish-expand-from-home/spec.md`](../specs/026-locker-wish-expand-from-home/spec.md):

* **the two homepage invitations now finish what they start.** "I want a locker!" and "I want to
  switch my locker!" (010) used to land on the locker wishes screen with the search form folded shut
  behind a summary — asking, in effect, the same question twice. They now arrive with that zone
  already open and the cursor already in the Floor field, so typing a floor is the only thing left to
  do;
* **the menu asks a different question, and gets a different screen.** Reaching locker wishes from the
  site menu, a bookmark, or any address that is not one of the two invitations still opens folded,
  exactly as it always has — the distinction is the whole feature, not a side effect of one path
  changing;
* **the intention belongs to one arrival and is spent by it.** It never touches the address: a reload,
  or Back to the same screen, shows it folded again, the same page the menu would have given, because
  the address a person can bookmark or share can never disagree with what it shows;
* it is **one rule at every width.** The zone opens and the field takes focus on a phone exactly as on
  a desktop — the on-screen keyboard that follows is accepted as the point of having pressed the
  invitation in the first place;
* somebody who has already declared a search sees **nothing different**: "See my locker searches!"
  (010) and the panel it opens are untouched by this feature.

What feature 027 adds — see
[`specs/027-admin-user-detail-view/spec.md`](../specs/027-admin-user-detail-view/spec.md):

* **a link within each row, not the row itself,** takes an administrator from Users (013) to a screen
  of its own for that one account — admin-only whichever way it is reached, exactly like every other
  admin destination;
* **everything about the account lives on one screen now.** Email, role and grant provenance, floor,
  locker, whether a locker search is standing or the account is party to an active swap — facts that
  used to mean cross-referencing the Users list and the locker wishes screen, and that had no home at
  all for a second account's proposal history;
* **the full proposal history, not just the active one.** Every proposal that account has ever sent or
  received, in any status, newest first, with its counterpart, its outcome, and the terms involved —
  the same shape of history the account holder already sees for themselves, read here for somebody
  else;
* **a pencil icon corrects floor and locker on the account's behalf**, pre-filled with what is on file
  and governed by the same rules a self-service edit already follows — a floor is required, a locker
  number must be free on that floor, and neither can move while a swap proposal is outstanding;
* **a button cancels a standing search on the account's behalf**, behind a confirmation naming what is
  about to be removed — guarded, unlike the account holder's own single-click cancel, because it acts
  on somebody else's account rather than the administrator's own;
* **both actions leave a trace.** Which administrator edited the floor/locker, or cancelled the
  search, and when — the same shape of provenance already kept for who granted administrator rights,
  so a detail screen always says who last touched it and not just what changed.

What feature 028 adds — see
[`specs/028-move-admin-grant-button/spec.md`](../specs/028-move-admin-grant-button/spec.md):

* **the grant control left the Users list and moved onto the account's own detail screen** (027) — the
  list has one fewer column now, an "Actions" column that held one control for one role and nothing
  else;
* **revoking is new capability, not a relocation.** Until now the only way to stop being an
  administrator was to cancel the account outright; a revoke control, guarded by the same plain
  confirmation grant already uses — no password, the account named on screen — sits beside the grant
  control wherever it applies;
* **an administrator can never revoke their own rights.** The control is not offered on their own
  detail screen, and a direct request against their own account is refused the same way — whether or
  not they are the only administrator on the site, there is no special case that would let the last
  one remove themselves;
* **revoking clears the record, it does not add to it.** An account reverted to standard shows no
  trace of who granted it rights or when — a later grant starts a fresh record rather than reviving the
  old one.

What feature 029 adds — see
[`specs/029-super-admin-role/spec.md`](../specs/029-super-admin-role/spec.md):

* **the first account is no longer just "the administrator" — it is the super admin**, a role named
  outright rather than left implicit in which row has no grantor behind it. Nothing about how it is
  obtained changes: it is still decided once, automatically, at the very first registration, with
  nothing to configure and nobody able to claim it afterward;
* **one screen became narrower, not the whole site.** The Danger Zone (016) is the super admin's
  alone now; every other administrator keeps everything else they already had — *Users*, granting and
  revoking rights, an account's own detail screen — and loses only this one destination, both the
  entry in the Admin menu and the address itself when typed, bookmarked or guessed;
* **the role cannot be handed on, taken, or given up while anyone else is on the site.** No control
  anywhere grants it to a second account, and none revokes it from the one that holds it — not even
  from that account's own hands. Cancelling that one account is refused for as long as anyone else is
  registered, because there would be nobody left who could ever hold the role again. The one exception
  is that account being the last one left on the whole site: that returns things to exactly the empty
  state the role is decided from, so whoever registers next claims it the same way the first one did;
* **every other administrator's own account stopped being a special case.** The rule that used to keep
  the site from being left with nobody in charge is gone, because the super admin's own permanence now
  keeps that promise more strongly on its own — an administrator whose rights were granted may cancel
  their own account at any time, however many other administrators remain;
* **the badge says which one it is.** A role held by one account, with one capability the others do
  not share, reads as *Super Admin* rather than the plain *Admin* every granted administrator's row
  still carries — on the Users list and on that account's own detail screen alike.

What feature 030 adds — see
[`specs/030-configurable-floors-locker-format/spec.md`](../specs/030-configurable-floors-locker-format/spec.md):

* **the building's floors are listed once, by the super admin**, on the Danger Zone, as one
  comma-separated line — `RDC, 1, 2, 3`. Spaces are trimmed, empty entries dropped and a repeated floor
  kept once; the order typed is the order offered, because no sort could know that *RDC* comes before
  *1* or where a mezzanine sits. An empty list is refused, so once a list exists it can be changed but
  never removed;
* **every floor field then becomes a choice from that list** — your own locker details, the floor you
  are looking for, and an administrator correcting somebody else's — and a floor outside it is refused
  on every one of them, including a request built by hand rather than sent from the form. Two people on
  the same floor are now written down the same way, which is what lets a swap match find them;
* **nothing changes until the list is saved.** A new instance, or one updated to this version, keeps
  floors as free text exactly as before; the Danger Zone says so rather than showing an empty field;
* **removing a floor strands nobody.** Anyone already on a floor that has left the list keeps it — still
  shown, still filtered on, still matched — and finds it selected in their form, marked *(no longer
  offered)*, so they can change their locker number without being made to move. Only choosing a
  different floor has to land on a listed one;
* **the super admin can set the format every locker number must follow**, written as a regular
  expression — `\d{3}` for exactly three digits, `\d{1,3}` for one to three — with an optional
  description in plain words, *3 digits, e.g. 042*, which is what people entering a number are shown
  instead of the pattern. The whole number has to match, never just part of it; surrounding spaces are
  ignored, and an empty number is still the ordinary answer of someone with no locker;
* **the screen explains the notation instead of assuming it.** Beside the field, a table of example
  patterns shows what each one means and which sample numbers it accepts and refuses — and those
  verdicts are worked out by the very check that enforces the format, so the screen can never claim
  something the site does not do. A pattern that is not a valid regular expression is refused, and the
  format already in force stays;
* **numbers already on file are left alone.** Setting or tightening a format rewrites nobody's locker
  number and blocks nothing; a number that does not follow it is kept until it is next changed, and the
  change has to follow it. Past swap proposals keep the floor and number they were recorded with.

What feature 031 adds — see
[`specs/031-locker-map-zones/spec.md`](../specs/031-locker-map-zones/spec.md):

* **an admin-only Locker Map screen says which lockers actually exist, and where.** Reachable from the
  same Admin menu entry as *Users* — no narrower than that, unlike the Danger Zone — it lets an
  administrator declare, floor by floor, the **zones** the building is divided into and, inside each
  one, the exact locker numbers physically in it;
* **a zone is a name and a floor, and the floor is fixed the moment it is created.** Relocating one
  means deleting it and starting again on the right floor rather than editing it into place — a zone is
  a physical location, not a label free to drift. Its name has to be unique among the zones on that one
  floor and nowhere else: the same name is free to reuse a floor up;
* **the floor + locker number pair is still the whole of what makes a locker unique** — 006's rule,
  untouched. The zone a locker sits in is a label attached to that pair, not part of its identity, so
  the same number can never be declared twice on one floor whichever zone the second attempt names —
  it is refused, naming the zone that already holds it;
* **every existing locker-number field keeps taking anything typed into it, but only accepts what the
  map already recognises.** Your own locker details and an administrator's edit of somebody else's are
  both checked against it now — and not the locker number in isolation either: changing only your floor
  re-checks the whole pair, since the same digits on a different floor are a different locker that may
  not be declared there;
* **nothing changes until the first locker is ever declared, anywhere on the site.** A fresh instance,
  or one updated to this version, keeps accepting any floor and locker number exactly as it always has —
  the same "inert until switched on" posture 030 gave the floor list and the locker format. The moment
  an administrator declares one locker, in one zone, on one floor, the check goes live everywhere at
  once;
* **removing a locker, or deleting a zone outright, strands nobody already on it.** An account's saved
  floor and locker number keep displaying exactly as before — deleting a zone cascades to every locker
  it held, in one action, with no separate emptying step required — but re-saving that same pair
  afterward is treated as new and refused until a zone declares it again;
* **the field stays free text everywhere.** No dropdown, no list to choose from while typing — the only
  thing that changed is what a save is willing to accept.

What feature 032 adds — see
[`specs/032-locker-zone-visibility/spec.md`](../specs/032-locker-zone-visibility/spec.md):

* **a locker's zone now shows up everywhere its floor and number already do** — your own locker card on
  the homepage, the locker search list, a swap proposal received, an exchange in progress, and the admin
  account directory and detail page — whenever an administrator has declared that floor + locker pair in
  the Locker Map (031). A locker nobody has mapped yet displays exactly as it always has: no zone, no
  error, the ordinary state it was before this feature existed;
* **the two tables that already give a locker number its own cell get a "Zone" column of its own too** —
  the account directory and the locker search list — with an explicit *No zone* placeholder, the same
  voice as their neighbouring *Not set*/*No locker assigned* columns, rather than folding the zone into
  the locker cell;
* **your own locker card matches Floor and Locker number exactly**: the zone is a third field in the same
  grid, no colon on its label, the same row at desktop and the same bold label at every width — not the
  inline sentence every other screen uses for it;
* **a received proposal reads the zone as one more fact about the locker, on the same line as floor and
  number**, with the date it was sent moved to its own line below in a fixed `day/month/year à hour:minute`
  format reserved for that one field — a deliberate, narrow exception to 025's "dates keep one format
  regardless of language" rule, since this new format is itself still identical in both languages, never
  translated;
* **it is read live, never cached.** Renaming a zone, or moving a locker out of it, shows up everywhere
  that locker is displayed the very next time each screen is shown — there is nothing to invalidate and
  no separate step;
* **swap history says nothing about zones.** Each row there already combines two people's floor and
  locker into one sentence, and a single column cannot cleanly carry two different zones — so the
  *Locker details* column reads exactly as it did before this feature, on both the self-service history
  screen and the admin detail page's;
* **no schema change.** The zone comes from a single batched, indexed lookup against 031's existing
  `Zone`/`LockerMapEntry` tables — one query per screen, never one per row, whatever the size of the
  list it is answering for.

What feature 033 adds — see
[`specs/033-admin-swap-validation/spec.md`](../specs/033-admin-swap-validation/spec.md):

* **finalizing a swap is now facilities services' call, not the two colleagues'.** Swapping lockers
  means re-associating badges in a system LockSwap does not reach, so the swap is only real once the
  people who do that have done it. Once a proposal is accepted, the exchange waits for an administrator;
* **an admin-only Swap validations screen lists every exchange waiting on that decision**, oldest first
  so nothing waits indefinitely, each naming both people with their floor, locker and zone. It sits in
  the Admin menu beside *Users* and the *Locker Map*, open to every administrator — not narrowed to the
  super admin the way the Danger Zone is;
* **validating does exactly what the old self-confirmation did**: the two accounts' floor and locker
  number are swapped, both wishes are cleared, and the exchange reads as completed in both histories;
* **refusing moves nobody's locker**, takes an optional reason that both people see the same way they
  see any other decline comment, and releases both of them at once to propose or accept a different
  swap;
* **every decision records which administrator made it.** The record outlives the administrator's
  own account: cancelling it later clears the name, never the decision;
* **two administrators acting on the same exchange cannot both win.** Whoever is second is told it has
  already been validated or refused, and nothing is applied twice;
* **an administrator may settle an exchange they are part of**, like any other — the screen makes no
  exception based on who is signed in;
* **neither colleague has a control any more.** The *Confirm exchange completed* button and its route
  are gone rather than hidden; both people see the exchange as **Awaiting validation**
  (*En attente de validation*) and are told to see facilities services to swap the lockers physically and
  finalize the request. The proposal history's status badge says the same thing, so the two screens
  never contradict each other;
* **nothing to migrate.** An exchange already accepted before this version, still waiting on the
  confirmation that no longer exists, simply appears in the queue like any other.

What feature 034 adds — see
[`specs/034-email-confirmation-password-reset/spec.md`](../specs/034-email-confirmation-password-reset/spec.md),
and [📧 Email](email.md) for how mail is sent and configured:

* **an account has to be activated before it can sign in.** Signing up creates the account and emails
  an activation link, valid 24 hours; the person lands on the sign-in page, told to check their inbox,
  and is **not** signed in. This is a deliberate change to 001, where signing up signed you straight in;
* **the right password is not enough before activation**, and the refusal says so — but only to someone
  who typed the right password. A wrong one still gets the same "Invalid email or password" as always,
  so the message never reveals that an account exists;
* **"Didn't receive the activation email?"** on the sign-in page sends a fresh link; every earlier link
  stops working the moment a new one is issued;
* **"Forgot your password?"** on the sign-in page emails a link to choose a new password — valid 6
  hours, usable once. Completing it signs you in, and also activates an account that never was and ends
  a 15-minute lockout (001), since following the link proves you own the mailbox;
* **both screens always give the same answer**, whether or not the address has an account, and send at
  most one email per address every 5 minutes;
* **changing your email address** from the account page emails a confirmation link to the new address;
  the old one stays in force until it is followed, and the account page says which address is waiting;
* **every password change sends a notice** to the account's address, with the time and "contact an
  administrator if this wasn't you" — and no link;
* **administrators see who has not activated**: the Users list marks those accounts *Not activated*, and
  the account's own page can activate it by hand, recording which administrator did it and when. No
  email is sent — it is the way out when email is the problem;
* **everyone already registered is activated by the upgrade** — nobody who could sign in before this
  version is asked to do anything;
* **emails are sent in the background**, in the site's language, as HTML and plain text, from a layout
  that follows the site's own design tokens. A slow or broken mail server never slows down or breaks a
  page.

