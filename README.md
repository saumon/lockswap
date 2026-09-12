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
* **Reliable** — a locker can never be assigned to two people at once.
* **Extensible** — the application can progressively integrate with the company's tools and systems.

## 🚀 Vision

LockSwap could grow into a genuine platform for the **collaborative management of individual spaces at work**: lockers, desks, parking spots, or any other shared resource.

The locker is only the starting point.

## 📍 Status

The project starts with the foundations: without user accounts, no locker swap is possible.

| Feature | Status |
| --- | --- |
| **001 — Signup and login** | ✅ Shipped |
| Lockers and current assignment | ⏳ To be specified |
| Offering and accepting a swap | ⏳ To be specified |
| History of changes | ⏳ To be specified |

What feature 001 covers today — see
[`specs/001-user-authentication/spec.md`](specs/001-user-authentication/spec.md):

* account creation with an email and a password (8 characters minimum, one account per address);
* login that leads straight to the homepage, which is closed to visitors who are not logged in;
* a session that persists for 30 days, browser restarts included, until the user logs out;
* a generic failure message, identical whether the email is unknown or the password is wrong;
* the account is locked for 15 minutes after 5 consecutive failures.

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
bin/rails test         # models
bin/rails test:system  # end-to-end signup, login, lockout, and redirect flows
bin/rubocop            # lint (zero warnings tolerated)
bin/brakeman           # static security analysis
```

CI replays all of it on every pull request ([`.github/workflows/ci.yml`](.github/workflows/ci.yml));
a failure blocks the merge.

## 🔍 Validate a feature by hand

[`specs/001-user-authentication/quickstart.md`](specs/001-user-authentication/quickstart.md) walks
through every acceptance scenario: signup, login, the 30-day session, logout, the generic failure
message, and the 15-minute lockout.

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
