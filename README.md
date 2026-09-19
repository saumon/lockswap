<!--
  The stacked lock-up, in the same order the sign-in screen uses it: mark over
  wordmark over tagline. The artwork is the one that ships — app/assets/images,
  the 800x600 downscale of brand/brand-mark-source.png — rather than a copy kept
  for this file, so there is one image to change if the brand ever moves.

  Its background is transparent, so it sits on GitHub's light and dark themes
  alike. Drawn at 220px from an 800px source, which keeps it sharp on a retina
  display. The wordmark is text rather than part of the image: it stays the
  document's <h1>, so GitHub still has a title to put in its own chrome, and it
  stays selectable and readable to a screen reader.

  alt is empty on purpose — the <h1> immediately below already names the brand,
  and a screen reader announcing both would simply say it twice. Same reasoning
  as shared/_brand_stacked.html.erb.
-->
<p align="center">
  <img src="app/assets/images/brand-mark.png" alt="" width="350">
</p>

<h1 align="center">LockSwap</h1>

<p align="center"><em>Find the locker that suits you</em></p>

<p align="center">
  <a href=".rubocop.yml"><img alt="RuboCop" src="https://img.shields.io/badge/code_style-rubocop--rails--omakase-brightgreen?style=flat-square"></a>
  <a href="#-method-spec-driven-development"><img alt="SDD" src="https://img.shields.io/badge/SDD-Spec--Driven%20Development-6E56CF?style=flat-square"></a>
  <a href="https://github.com/github/spec-kit"><img alt="Spec Kit" src="https://img.shields.io/badge/Spec%20Kit-github%2Fspec--kit-24292F?style=flat-square&logo=github&logoColor=white"></a>
</p>

<p align="center">
  <a href=".ruby-version"><img alt="Ruby" src="https://img.shields.io/badge/Ruby-3.4.6-CC342D?style=flat-square&logo=ruby&logoColor=white"></a>
  <a href="Gemfile"><img alt="Rails" src="https://img.shields.io/badge/Rails-8.1.3-D30001?style=flat-square&logo=rubyonrails&logoColor=white"></a>
  <a href="config/initializers/devise.rb"><img alt="Devise" src="https://img.shields.io/badge/Auth-Devise-525252?style=flat-square"></a>
  <a href="app/assets/tailwind/application.css"><img alt="Tailwind CSS" src="https://img.shields.io/badge/Tailwind%20CSS-4.3-38BDF8?style=flat-square&logo=tailwindcss&logoColor=white"></a>
  <a href="config/database.yml"><img alt="SQLite" src="https://img.shields.io/badge/SQLite-3-003B57?style=flat-square&logo=sqlite&logoColor=white"></a>
  <a href="config/deploy.yml"><img alt="Kamal" src="https://img.shields.io/badge/Deploy-Kamal-0A66C2?style=flat-square&logo=docker&logoColor=white"></a>
</p>

**LockSwap** is an application that lets the employees of a company **swap lockers with each other, easily**.

Is your locker too far from your desk? Too small? Badly placed? Would a colleague be glad to take your spot? LockSwap makes it simple to find someone to swap with.

## 💡 The idea

In many companies, lockers are assigned to employees in a fairly static way. When someone moves desk, changes team, or simply wants a more practical spot, the change quickly turns into an administrative errand.

**LockSwap turns that exchange into a simple, direct, transparent operation between colleagues.**

An employee can:

1. look up their current locker;
2. flag that they would like to change;
3. browse the lockers available for a swap;
4. offer a swap to a colleague;
5. accept or decline an offer;
6. confirm the completed swap.

The application then keeps locker assignments up to date automatically, and keeps the history of every change.

## 🎯 Goal

> **Make changing lockers as simple as handing an object to a colleague.**

LockSwap aims to cut the administrative work of managing lockers while giving employees more autonomy.

## ✨ Principles

* **Simple** — a few clicks are enough to offer or complete a swap.
* **Collaborative** — employees find swap opportunities directly among themselves.
* **Secure** — only authorised people can view or change assignments.
* **Traceable** — every change is recorded.
* **Reliable** — one locker, one holder: a given number on a given floor can never be assigned to two
  people at once.
* **Extensible** — the application can progressively integrate with the company's tools and systems.

## 🚀 Vision

LockSwap could grow into a genuine platform for the **collaborative management of individual spaces at work**: lockers, desks, parking spots, or any other shared resource.

The locker is only the starting point.

## 📍 Status

The project started with the foundations — without user accounts, no locker swap is possible — and
now carries the swap through end to end: declare what you are looking for, offer a swap, answer one,
and confirm it once the lockers have actually changed hands. The details being negotiated are held
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
who to approach costs one action instead of two.

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
| Locker directory and availability | ⏳ To be specified |

What feature 001 covers today — see
[`specs/001-user-authentication/spec.md`](specs/001-user-authentication/spec.md):

* account creation with an email and a password (8 characters minimum, one account per address);
* login that leads straight to the homepage, which is closed to visitors who are not logged in;
* a session that persists for 30 days, browser restarts included, until the user logs out;
* a generic failure message, identical whether the email is unknown or the password is wrong;
* the account is locked for 15 minutes after 5 consecutive failures.

What feature 002 adds — see
[`specs/002-locker-floor-profile/spec.md`](specs/002-locker-floor-profile/spec.md):

* the floor and the locker number are shown on the homepage as soon as they are on file;
* a user who has filled in nothing yet is asked for them right there, as **two separate fields**;
* the floor is required; the locker number is not, because having no locker assigned is an ordinary
  state and is displayed as such, never as an error;
* a locker number belongs to one account at a time — a clash is refused without ever revealing who
  holds it, and the database enforces that even when two people submit at the same moment (scoped to
  a single floor since 006, below);
* the details can be changed later, behind a control that keeps the form out of the way so the
  homepage reports a settled state instead of standing permanently open for editing — a labelled bar
  at the time, a **pencil** in the corner of the card since 009, below.

What feature 003 adds — see
[`specs/003-locker-search-wish/spec.md`](specs/003-locker-search-wish/spec.md):

* a **I'm looking for a locker** button declares that you are looking for a locker, and asks which floor
  before recording anything;
* one wish per account — declaring again moves the existing wish to the new floor instead of adding a
  second, and the database enforces that even when two declarations land at the same moment;
* the floor is required (blank or whitespace is refused) and free-form, exactly as on the profile;
* having no locker assigned is no obstacle to declaring a wish, and already holding one is precisely
  the point of a swap — neither blocks anything;
* a **Locker wishes** page lists every active wish to any logged-in user: who is looking (by email),
  the floor they are after, and the floor and locker they hold today — or that they hold none, said
  plainly rather than as an error — so a worthwhile swap is obvious at a glance;
* a wish can be cancelled at any time, which takes it off that list for everyone.

What feature 004 adds — see
[`specs/004-locker-swap-proposal/spec.md`](specs/004-locker-swap-proposal/spec.md):

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
  floor and locker number between the two accounts and clears both wishes, the need now being settled;
* a **Proposal history** page lists every proposal you sent or received — direction, the other person,
  the date, where it ended up, and any decline comment — read-only, because the homepage is where
  proposals are acted on and this is where they are looked back at.

What feature 005 adds — see
[`specs/005-swap-lock-history-comment/spec.md`](specs/005-swap-lock-history-comment/spec.md):

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
[`specs/006-locker-floor-uniqueness/spec.md`](specs/006-locker-floor-uniqueness/spec.md):

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
[`specs/007-toast-notifications/spec.md`](specs/007-toast-notifications/spec.md):

* the lines the application answers with — **Signed in successfully.**, **Locker details saved.**, and
  every other one — used to be a block of text wedged at the top of the page that stayed there until
  something else replaced it; they now arrive as a **notification that takes itself away after three
  seconds**;
* nothing moves when one comes or goes: the message floats at the top right, below the header,
  instead of taking a strip out of the page — so the content underneath neither jumps down on arrival
  nor springs back on departure, the navigation stays visible and clickable throughout, and on a wide
  screen the message sits over the empty margin beside the content rather than over the content
  itself;
* **the countdown stops while the pointer is resting on a message, or while the keyboard has landed
  on it**, and picks up where it left off once you move away — three seconds is not long enough for
  every reader, and a message that vanishes mid-sentence cannot be asked for a second time;
* a reader who is already done can dismiss one by hand rather than waiting the rest of the countdown
  out;
* a success still reads as a success and a refusal as a refusal, at a glance and without reading the
  words — and each keeps the role that has a screen reader announce it, politely for a confirmation
  and insistently for a failure;
* two messages on the same page stack rather than one quietly standing in for the other, and a long
  one wraps and grows downwards instead of spilling out of the window.

What feature 008 brings — see
[`specs/008-visual-identity-refresh/spec.md`](specs/008-visual-identity-refresh/spec.md):

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
[`specs/009-locker-entry-pencil-edit/spec.md`](specs/009-locker-entry-pencil-edit/spec.md):

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
[`specs/010-homepage-locker-wish-block/spec.md`](specs/010-homepage-locker-wish-block/spec.md):

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
  which every state links to in a single click or keypress;
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
[`specs/011-logo-fade-loop/spec.md`](specs/011-logo-fade-loop/spec.md):

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
[`specs/012-responsive-layout-menu/spec.md`](specs/012-responsive-layout-menu/spec.md):

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
[`specs/013-admin-user-directory/spec.md`](specs/013-admin-user-directory/spec.md). Four of the
statements below describe 013 as it shipped and **no longer describe the application**: feature 015
lifted the one-administrator limit, gave the Users screen its one control, and closed the case where
the site could be left with nobody in charge. They are marked where they occur:

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
  application cannot keep. **Superseded by 015**, which added the capability first and the control
  second, in that order; demote, edit and delete are still absent, and still for this reason;
* it is **a table on a desktop and one labelled card per account on a phone**, from the same markup
  rendered once, on the single breakpoint 012 established — a new screen joins those rules rather
  than arriving with its own. It is audited for accessibility like every other screen, at both
  widths, and so is the Admin menu with its submenu open: a state that exists on one account's pages
  and would otherwise never have been looked at.

What feature 014 adds — see
[`specs/014-confirmation-mot-de-passe/spec.md`](specs/014-confirmation-mot-de-passe/spec.md):

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
[`specs/015-grant-admin-rights/spec.md`](specs/015-grant-admin-rights/spec.md):

* **an administrator can hand the role to somebody else**, from a button on that account's row in
  the list they already had. Nothing happens on the press: a confirmation names the account and says
  the grant cannot be undone, and only validating it does anything. It is the same construction the
  *Cancel my account* button has always used — the site's one existing way of asking "are you sure?"
  — rather than a modal written for the occasion;
* **no password is asked for on the way through**, which is exactly why the confirmation has to say
  the grant is permanent. That dialog is the only thing between a pointer and an irreversible change,
  and a confirmation that only confirms would be leaning on the reader already knowing what it costs.
  Re-typing a password was considered and turned down for consistency: the closest thing the
  application already does — closing your own account, which is no less final — is guarded by a
  confirmation and nothing more;
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
  were written, not a promise anyone has to keep remembering;
* **each row says where its rights came from**: *First registration*, or *Granted by* somebody *on* a
  date. It is not a log. The role is granted at most once and never taken back, so its origin is a
  single fact about the account rather than a history of events to page through — and it **outlives
  the account that granted it**: when that person leaves, the row reads *Granted on* a date
  *(account removed)* rather than quietly going blank where a name used to be;
* **granting is the whole of what was added.** 013 named four things this screen would not do —
  promote, demote, edit, delete — and gave the same reason for all four: there was no capability
  behind any of them, and a control that looked like one would be a promise the application could not
  keep. Exactly one of the four has a capability behind it now, so exactly one of them got a control.
  The other three are still absent, and still for that reason rather than for lack of time;
* **the last administrator cannot walk out.** Granting became the only way into the role and nothing
  takes it away, which left cancelling an account as the only way out of it — and the way out led
  somewhere with no way back, since the role is only ever claimed automatically on a site with no
  accounts at all. So the cancellation is refused while other accounts remain, and the person is told
  what to do about it rather than merely stopped. The one case it lets through is the sole account
  left on a site: there is nobody to lock out, and whoever registers next claims the role exactly as
  the first one did;
* **the control says which account it acts on**, to a screen reader as well as to the eye. A column
  of buttons all reading *Grant admin rights* is a column of identical buttons, and leaves somebody
  who cannot see the row counting their way down it — so each one carries the account's address in
  its accessible name. The screen stays a table on a desktop and one labelled card per account on a
  phone, on the single breakpoint 012 established, and goes through the same accessibility audit as
  every other screen at both widths.

What feature 016 adds — see
[`specs/016-danger-zone-email-domains/spec.md`](specs/016-danger-zone-email-domains/spec.md):

* **the site can decide who is allowed to sign up at all**, by email domain. A **Danger Zone** screen,
  in the Admin menu beside *Users*, holds the list of domains that may create an account: with
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
[`specs/017-locker-wishes-floor-filter/spec.md`](specs/017-locker-wishes-floor-filter/spec.md):

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
[`specs/018-wishes-match-tag/spec.md`](specs/018-wishes-match-tag/spec.md):

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
[`specs/019-floor-filter-prefill/spec.md`](specs/019-floor-filter-prefill/spec.md):

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

## 🧭 Method: Spec-Driven Development

The project is built with **SDD** using [Spec Kit](https://github.com/github/spec-kit): the
specification is the source of truth, and the code follows from it. Every feature goes through the
same chain of commands, whose artifacts are versioned under `specs/`:

| Command | Produces | Role |
| --- | --- | --- |
| `/speckit-specify` | `spec.md` | the business need, free of technical choices |
| `/speckit-clarify` | `spec.md` | resolves ambiguities through targeted questions |
| `/speckit-plan` | `plan.md`, `research.md`, `data-model.md`, `contracts/` | the architecture and the technical decisions |
| `/speckit-tasks` | `tasks.md` | the ordered breakdown into tasks |
| `/speckit-analyze` | — | checks the three documents against each other |
| `/speckit-implement` | the code | runs the tasks, tests first |

The project's non-negotiable rules (code quality, testing, experience consistency, performance) live
in [`.specify/memory/constitution.md`](.specify/memory/constitution.md) and are checked at the
`plan` stage.

## 🛠️ Stack

A conventional Rails monolith, server-rendered, with no separate frontend.

| Piece | Choice |
| --- | --- |
| Language | Ruby 3.4.6 |
| Framework | Ruby on Rails 8.1.3 |
| Authentication | Devise (`database_authenticatable`, `registerable`, `rememberable`, `lockable`, `validatable`) |
| Database | SQLite through Active Record |
| Styling | Tailwind CSS 4.3 (the `tailwindcss-rails` gem, no Node dependency), with the design tokens declared in `@theme` |
| Layout | Responsive from 320 px up, on a single breakpoint at 48 rem (768 px) — enforced by a test, not by convention |
| Typeface | Nunito, self-hosted (SIL OFL) — one variable file, latin subset, no third-party font host |
| Browser behaviour | Hotwire — Turbo, and Stimulus over importmap; no bundler, no `package.json` |
| App server | Puma |
| Tests | Minitest + Rails system tests (Capybara, headless Chrome), with axe-core accessibility audits |
| Quality | RuboCop (`rubocop-rails-omakase`), Brakeman |
| Deployment | Docker + Kamal |

## ⚙️ Requirements

* Ruby 3.4.6 (see [`.ruby-version`](.ruby-version))
* SQLite 3.8+
* Google Chrome (for the system tests)

## 📥 Setup

```sh
bundle install
bin/rails db:prepare
```

## ▶️ Run

```sh
bin/dev          # Puma + the Tailwind watcher (via Procfile.dev)
# or
bin/rails server # server only; run bin/rails tailwindcss:build first
```

The app answers on `http://localhost:3000`. It redirects to the login page until an account exists:
start at `/users/sign_up`.

## ✅ Tests and quality

```sh
bin/rails test         # models, controllers, views, and the single-breakpoint rule
bin/rails test:system  # end-to-end signup (password confirmation and reveal included), login, lockout, redirect,
                       # locker-details, wish, swap, notification, and admin flows,
                       # plus an accessibility audit of every screen, the reduced-motion behaviour,
                       # and a sweep of every screen at both a phone and a desktop viewport
bin/rubocop            # lint (zero warnings tolerated)
bin/brakeman           # static security analysis
```

CI replays all of it on every pull request ([`.github/workflows/ci.yml`](.github/workflows/ci.yml));
a failure blocks the merge.

The accessibility audit runs as an ordinary system test, screen by screen, so a contrast failure or a
control that cannot be reached by keyboard breaks the build like any other regression. It carries one
documented exemption — the colour contrast of the brand wordmark, which the WCAG standard exempts as
a logotype — and that exemption is scoped to that one element and that one rule.

Since 012 the same suite also drives the **viewport itself**, at a phone width and a desktop width,
and asserts the things that have to be true of every screen at both: that the page does not scroll
sideways, that the menu is in the treatment that width calls for, that the lists are in theirs, and
that every standalone control is a large enough target. It measures rather than assumes — the
assertion fails if it finds nothing to measure, because a check that quietly measures nothing passes
for ever.

One practical note: the system tests serve the **compiled** stylesheet. `bin/rails test:system`
rebuilds it for you, but running a single test file directly does not, so a stylesheet change that
has not been built will read as a failing assertion about the layout rather than as a missing step:

```sh
bin/rails tailwindcss:build && bin/rails test test/system/responsive_test.rb
```

`bin/dev` runs the watcher, so this does not come up while the app is running.

## 🔍 Validate a feature by hand

Each feature ships a quickstart that walks through its acceptance scenarios by hand:

* [`specs/001-user-authentication/quickstart.md`](specs/001-user-authentication/quickstart.md) —
  signup, login, the 30-day session, logout, the generic failure message, and the 15-minute lockout;
* [`specs/002-locker-floor-profile/quickstart.md`](specs/002-locker-floor-profile/quickstart.md) —
  filling in a floor with and without a locker number, the rejected blank floor, a locker number
  already taken by someone else, and editing either value afterwards;
* [`specs/003-locker-search-wish/quickstart.md`](specs/003-locker-search-wish/quickstart.md) —
  declaring a wish, the rejected blank floor, moving an existing wish to another floor, the list as
  other people see it, and cancelling;
* [`specs/004-locker-swap-proposal/quickstart.md`](specs/004-locker-swap-proposal/quickstart.md) —
  proposing a swap, the refusals (yourself, a duplicate, someone already mid-swap), answering one
  either way, withdrawing, confirming the exchange and watching both lockers change hands, and the
  history screen;
* [`specs/005-swap-lock-history-comment/quickstart.md`](specs/005-swap-lock-history-comment/quickstart.md) —
  the edit control giving way while a proposal is outstanding, first-time details still accepted from
  someone who has none, the hold lifting once the swap is settled, and a history summary that stays
  put after both profiles have moved on;
* [`specs/006-locker-floor-uniqueness/quickstart.md`](specs/006-locker-floor-uniqueness/quickstart.md) —
  the same locker number claimed on two different floors, the clash still refused on one and the same
  floor, moving a number to a free floor and being refused an occupied one, the vacated pair claimed
  by someone else, and the floor still required before any number is stored;
* [`specs/007-toast-notifications/quickstart.md`](specs/007-toast-notifications/quickstart.md) —
  a confirmation arriving and leaving on its own, a refusal doing the same in its own colour,
  dismissing one by hand, the countdown holding while the pointer rests on it, two of them stacking,
  and the page underneath staying exactly where it was;
* [`specs/008-visual-identity-refresh/quickstart.md`](specs/008-visual-identity-refresh/quickstart.md) —
  walking all twelve screens, the reduced-motion switch removing every animation while leaving the
  interface whole, no content waiting on a scroll to appear, the keyboard showing where it is
  throughout, nothing scrolling sideways at 360 px, the typeface loading without a flash of invisible
  text, and no request leaving for a third party;
* [`specs/009-locker-entry-pencil-edit/quickstart.md`](specs/009-locker-entry-pencil-edit/quickstart.md) —
  entering a locker on first sight of the app, saying you have none and being asked for nothing but a
  floor, taking that back with the floor intact, the blank floor still refused on that path, the
  pencil opening the plain form pre-filled, and the explanation still taking the pencil's place while
  a swap is outstanding;
* [`specs/010-homepage-locker-wish-block/quickstart.md`](specs/010-homepage-locker-wish-block/quickstart.md) —
  each of the three states on the account that produces it, the block absent entirely for an account
  that has filled in nothing, the wish appearing and disappearing on the homepage as it is declared
  and cancelled elsewhere, and the invitation still standing while a swap is outstanding;
* [`specs/011-logo-fade-loop/quickstart.md`](specs/011-logo-fade-loop/quickstart.md) —
  the sign-in and sign-up logo doing its one-off entrance and then breathing on past it, the header
  mark breathing from first paint and still going after a navigation, the mark still clicking through
  to the homepage mid-fade, and the reduced-motion switch leaving both of them perfectly still;
* [`specs/012-responsive-layout-menu/quickstart.md`](specs/012-responsive-layout-menu/quickstart.md) —
  narrowing the window through 768 px and watching the bar become a toggle and the lists become
  cards, the menu still opening and closing with JavaScript switched off, *Propose swap* on screen
  without a sideways swipe, and the two checks a headless browser cannot make: a form still usable
  with the on-screen keyboard up, and the page at 200% zoom;
* [`specs/013-admin-user-directory/quickstart.md`](specs/013-admin-user-directory/quickstart.md) —
  signing up first on an empty instance and finding the Admin menu there, signing up second and
  finding nothing, the address refused when the second account types it anyway, the directory listing
  both accounts oldest first with the badge on one of them, and the administrator deleting their own
  account to watch the role pass to nobody — that last step is **superseded by 015**, which refuses
  the cancellation instead;
* [`specs/015-grant-admin-rights/quickstart.md`](specs/015-grant-admin-rights/quickstart.md) —
  granting the role from the list and declining the confirmation first to watch nothing happen,
  signing in as the promoted account to find the menu there and grant the role onwards, the grant
  route refused for an account that never had the role, and the walk that proves the site keeps
  somebody in charge: administrators leaving one at a time until the last one is stopped, promoted
  somebody else, and then allowed to go — with the row they promoted still saying when it happened
  after they are gone;
* [`specs/014-confirmation-mot-de-passe/quickstart.md`](specs/014-confirmation-mot-de-passe/quickstart.md) —
  signing up with the two passwords agreeing and then with them differing, the message staying away
  until the confirmation field is first left and clearing itself as the mistake is corrected, each eye
  revealing its own field and leaving the other alone, both fields masked again after a reload, and
  the toggle reached and worked from the keyboard;
* [`specs/016-danger-zone-email-domains/quickstart.md`](specs/016-danger-zone-email-domains/quickstart.md) —
  listing a domain and watching a signup from anywhere else refused with the exact message while one
  from that domain goes through, lifting the restriction again by removing the last domain, the
  malformed and duplicate entries refused on the screen, a subdomain of a listed domain still refused
  until it is listed itself, an account whose domain is no longer allowed still signing in, and the
  screen and both of its write addresses refused to an account that is not an administrator;
* [`specs/017-locker-wishes-floor-filter/quickstart.md`](specs/017-locker-wishes-floor-filter/quickstart.md) —
  narrowing on each floor in turn and then on both at once, clearing either one independently, the
  floors offered in numeric order with 10 last, somebody who has saved no floor of their own dropping
  out of the *Their floor* filter and coming back when it is cleared, a combination nobody satisfies
  saying so in its own words, a nonsense floor typed into the address, the filters surviving a save
  and a cancel of your own wish, and the two checks a headless browser makes awkwardly: moving across
  the choices with a keyboard without the list re-filtering, and the filter bar wrapping on a phone;
* [`specs/018-wishes-match-tag/quickstart.md`](specs/018-wishes-match-tag/quickstart.md) —
  declaring a wish that reciprocates with someone else's and watching the tag appear on just that row,
  confirming it stays away with no wish of your own or no saved floor, confirming your own row never
  carries it, proposing a swap to a tagged row and watching the tag sit next to *Proposal pending*
  rather than disappear, the tag surviving a floor filter, and cancelling the wish to watch it go;
* [`specs/019-floor-filter-prefill/quickstart.md`](specs/019-floor-filter-prefill/quickstart.md) —
  declaring a wish and watching *Their floor* narrow the list without touching it, leaving and
  returning (or simply reloading) to find it narrowed again, picking a floor by hand and watching it
  survive an unrelated filter change and the Back button before a genuine reload lets it go, changing
  the wish to move the filter with it even over a manual choice, a rejected change leaving it exactly
  as it was, cancelling to watch it fall back to *All floors* and stay there on the next visit, and
  *Looking for floor* left alone throughout.

## 🚢 Deploy

The app ships as a Docker image and is deployed with [Kamal](https://kamal-deploy.org)
([`config/deploy.yml`](config/deploy.yml)).

### How Kamal works

Kamal is not a PaaS: it drives **your own servers over SSH**. One `kamal deploy` does roughly this:

1. builds the Docker image locally, from the `Dockerfile`;
2. pushes it to a container **registry** (Docker Hub, ghcr.io, …);
3. opens an **SSH connection to every host** listed under `servers:`;
4. through that connection, pulls the image and starts the new container behind `kamal-proxy`,
   moving traffic over with no downtime.

### Before the first deploy

`kamal init` generated `config/deploy.yml` with placeholder values. These three must be replaced, or
the deploy fails:

```yaml
image: your-user/lockswap     # "user/app" for an external registry

servers:
  web:
    - 203.0.113.42            # real IP or hostname; 192.168.0.1 is a placeholder

registry:
  server: ghcr.io             # localhost:5555 is a placeholder too
  username: your-user
  password:
    - KAMAL_REGISTRY_PASSWORD # resolved from .kamal/secrets
```

Then uncomment the line in [`.kamal/secrets`](.kamal/secrets) that pulls
`KAMAL_REGISTRY_PASSWORD` from your environment or password manager — no raw credential should ever
be committed.

On the server side:

* your **SSH public key** must be installed for the user Kamal logs in as: `root` by default,
  otherwise add `ssh: { user: deploy }` to `deploy.yml`;
* the **first** time, run `kamal setup` rather than `kamal deploy`: that is the command that
  installs Docker on the machine and puts the proxy in place.

To serve the app on a domain, uncomment the `proxy:` block (Let's Encrypt certificate) and set
`config.assume_ssl` and `config.force_ssl` to `true` in `config/environments/production.rb`.

### Deploying

```sh
kamal setup    # first time only: installs Docker and the proxy on the server
kamal deploy   # every time after that
```

### Persistent data

The SQLite databases live in `storage/`, mounted by `deploy.yml` as the `lockswap_storage` volume,
so accounts survive a redeploy. Verifiable locally:

```sh
docker build -t lockswap .
docker run -d -p 3000:80 -v lockswap_storage:/rails/storage \
  -e RAILS_MASTER_KEY=$(cat config/master.key) lockswap
```

### Troubleshooting

**`Error setting up port forwarding to 192.168.0.1: Errno::ENETUNREACH`** — Kamal is trying to SSH
into the placeholder address still sitting under `servers:`. `ENETUNREACH` means your machine has no
route to that address at all; a real host refusing the connection would report `ECONNREFUSED` or
time out instead. Replace the address as shown above.

**Registry push failures** — `registry.server` is still `localhost:5555`, or
`KAMAL_REGISTRY_PASSWORD` is not set in `.kamal/secrets`.

**`Host key verification failed` / permission denied** — your SSH key is not authorised for the user
Kamal logs in as (`root`, unless `ssh.user` names another).

---

**LockSwap — Swap your locker, not your day.**
