# Deployment

The app ships as a Docker image and is deployed with [Kamal](https://kamal-deploy.org)
([`config/deploy.yml`](../config/deploy.yml)).

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

Then uncomment the line in [`.kamal/secrets`](../.kamal/secrets) that pulls
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

### Mail

Production **must** be able to send email before it goes live: new accounts can only be activated
from an emailed link. Everything about it — how it works and how to point it at your SMTP server —
is in [📧 Email](email.md) above. The short version for a Kamal deploy: uncomment the `SMTP_*` lines in
[`config/deploy.yml`](../config/deploy.yml) and [`.kamal/secrets`](../.kamal/secrets), fill them in, and
redeploy.

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
