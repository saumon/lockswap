# Data Model: Login Greeting Popup

No persistent data. No migration.

## Greeting message (transient)

- **Lives in**: the flash for one request, key `greeting`.
- **Value**: the translated text of `devise.sessions.greeting` ("coucou" in en and fr).
- **Created**: when `sessions#create` signs a user in successfully.
- **Destroyed**: automatically after the next request (the landing page).
- **Not created**: on failed sign-in, sign-up, password reset, or any request with an existing session.
