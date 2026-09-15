# Contract: Locker Profile Update (reused, unchanged)

This feature introduces no new endpoint. Both the first-entry screen (either view) and the pencil-icon edit control submit to the same existing contract, established in `002-locker-floor-profile` and untouched here.

## `PATCH /locker_profile`

**Controller**: `LockerProfilesController#update`

**Auth**: Requires an authenticated session (`before_action :authenticate_user!`); redirects to sign-in otherwise (Devise default).

**Request params**:

| Param | Required | Notes |
|---|---|---|
| `user[floor]` | Yes | Rejected with "Floor can't be blank" if missing/blank, regardless of which UI path submitted it |
| `user[locker_number]` | No | Blank/absent is normalized to `nil` ("no locker"); must be unique among users sharing the same `floor` |

**Responses**:

| Outcome | Status | Body |
|---|---|---|
| Save succeeds | `302` redirect to `/` | Flash notice "Locker details saved." |
| Floor blank | `422 Unprocessable Entity` | Re-renders `home/index` with `"Floor can't be blank"` in `#error_explanation`, form fields repopulated with the rejected input |
| Locker number taken on that floor | `422 Unprocessable Entity` | Re-renders `home/index` with `User::LOCKER_NUMBER_TAKEN_MESSAGE` ("… is not available on that floor — another account already has this locker") without naming the other account |
| An active swap proposal holds the current values | Edit control not shown at all | N/A — request cannot be initiated through the UI in this state (005) |

**What this feature changes about the contract**: nothing. The first-entry "I don't have a locker 😔" view submits the identical two params (with `user[locker_number]` empty); the pencil-icon edit control submits the identical two params pre-filled with the current values. No new param, no new status code, no new response shape.
