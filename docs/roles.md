# Roles

Three roles exist on a LockSwap instance, and every registered account holds exactly one:

| Role | Who holds it | Can do |
| --- | --- | --- |
| **Standard** | Everyone who registers, by default | Manage their own floor and locker, declare a locker wish, send and answer swap proposals — everything an employee needs to agree a swap, which an administrator then validates ([033](../specs/033-admin-swap-validation/spec.md)). |
| **Admin** | Granted by an existing administrator, to any number of accounts ([015](../specs/015-grant-admin-rights/spec.md)) | Everything a standard account can, plus the **Users** directory ([013](../specs/013-admin-user-directory/spec.md)): view, edit floor/locker, and cancel a search on anyone's behalf ([027](../specs/027-admin-user-detail-view/spec.md)), activate by hand an account whose activation email never arrived ([034](../specs/034-email-confirmation-password-reset/spec.md)), grant or revoke administrator rights on any other account ([015](../specs/015-grant-admin-rights/spec.md), [028](../specs/028-move-admin-grant-button/spec.md)), declare the site's zones and known locker numbers on the **Locker Map** ([031](../specs/031-locker-map-zones/spec.md)), and validate or refuse accepted swaps on **Swap validations** ([033](../specs/033-admin-swap-validation/spec.md)). |
| **Super Admin** | Exactly one account, always: whichever one registered first on the site ([013](../specs/013-admin-user-directory/spec.md), named explicitly by [029](../specs/029-super-admin-role/spec.md)) | Everything an admin can, plus exclusive access to the **Danger Zone** ([016](../specs/016-danger-zone-email-domains/spec.md)) — the allowed email domains, the site's language ([025](../specs/025-multilingual-support/spec.md)), and the site's floor list and locker number format ([030](../specs/030-configurable-floors-locker-format/spec.md)). |

What makes the super admin different is not a bigger set of permissions layered on top — it is that
there is only ever one of them, and the site decides who it is rather than anyone choosing:

* **assigned automatically, once.** The account created by the very first registration on the site
  becomes the super admin at that moment, with nothing to configure; every account registered after it
  never can, however many admins the site goes on to have;
* **cannot be granted, transferred, or taken away.** No control anywhere makes a second account the
  super admin, and none moves the role off the one that holds it — including that account's own
  attempt to give it up. The only way the role ever changes hands is the site returning to zero
  accounts and a new registration claiming it fresh, exactly as the first one did;
* **the one account that can never leave while anyone else is still around.** Every admin whose rights
  were granted may cancel their own account whenever they like; the super admin's account is refused
  that, for as long as any other account exists, because nobody could ever take the role over
  afterward. It may still leave once it is the very last account on the site — which is not an
  exception so much as the same rule read the other way: at that point there is nobody left to strand.

