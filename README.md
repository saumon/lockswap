# LockSwap

[![RuboCop](https://img.shields.io/badge/code_style-rubocop--rails--omakase-brightgreen?style=flat-square)](.rubocop.yml)
[![SDD](https://img.shields.io/badge/SDD-Spec--Driven%20Development-6E56CF?style=flat-square)](#-method-spec-driven-development)
[![Spec Kit](https://img.shields.io/badge/Spec%20Kit-github%2Fspec--kit-24292F?style=flat-square&logo=github&logoColor=white)](https://github.com/github/spec-kit)

[![Ruby](https://img.shields.io/badge/Ruby-3.4.6-CC342D?style=flat-square&logo=ruby&logoColor=white)](.ruby-version)
[![Rails](https://img.shields.io/badge/Rails-8.1.3-D30001?style=flat-square&logo=rubyonrails&logoColor=white)](Gemfile)
[![Devise](https://img.shields.io/badge/Auth-Devise-525252?style=flat-square)](config/initializers/devise.rb)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind%20CSS-4.3-38BDF8?style=flat-square&logo=tailwindcss&logoColor=white)](app/assets/tailwind/application.css)
[![SQLite](https://img.shields.io/badge/SQLite-3-003B57?style=flat-square&logo=sqlite&logoColor=white)](config/database.yml)
[![Kamal](https://img.shields.io/badge/Deploy-Kamal-0A66C2?style=flat-square&logo=docker&logoColor=white)](config/deploy.yml)

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
the way.

| Feature | Status |
| --- | --- |
| **001 — Signup and login** | ✅ Shipped |
| **002 — Floor and locker details** | ✅ Shipped |
| **003 — Locker search wish** | ✅ Shipped |
| **004 — Locker swap proposals** | ✅ Shipped |
| **005 — Locker field lock and swap history** | ✅ Shipped |
| **006 — Per-floor locker numbers** | ✅ Shipped |
| **007 — Self-dismissing notifications** | ✅ Shipped |
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
* the details can be changed later, behind an **Edit locker details** control so the homepage reports
  a settled state instead of standing permanently open for editing.

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
* the **Edit locker details** control gives way to a plain explanation of why it is not available,
  rather than vanishing without a word or waiting to refuse the change after it has been typed;
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
| Styling | Tailwind CSS 4.3 (the `tailwindcss-rails` gem, no Node dependency) |
| Browser behaviour | Hotwire — Turbo, and Stimulus over importmap; no bundler, no `package.json` |
| App server | Puma |
| Tests | Minitest + Rails system tests (Capybara, headless Chrome) |
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
bin/rails test         # models, controllers, and views
bin/rails test:system  # end-to-end signup, login, lockout, redirect, locker-details, wish, swap, and notification flows
bin/rubocop            # lint (zero warnings tolerated)
bin/brakeman           # static security analysis
```

CI replays all of it on every pull request ([`.github/workflows/ci.yml`](.github/workflows/ci.yml));
a failure blocks the merge.

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
  and the page underneath staying exactly where it was.

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
