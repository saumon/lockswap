require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with an email and an 8-character password" do
    user = User.new(email: "new.person@example.com", password: "12345678")

    assert user.valid?, user.errors.full_messages.to_sentence
  end

  # FR-002: email is the account identifier, so it is required.
  test "requires an email" do
    user = User.new(email: "", password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires a well-formed email" do
    user = User.new(email: "not-an-email", password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "must look like an email address, for example name@example.com."
  end

  # FR-003: one account per email address.
  test "requires a unique email" do
    user = User.new(email: users(:alice).email, password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "is already registered. Log in instead, or sign up with a different address."
  end

  test "treats emails as unique case-insensitively" do
    user = User.new(email: users(:alice).email.upcase, password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "is already registered. Log in instead, or sign up with a different address."
  end

  # FR-002: passwords must be at least 8 characters.
  test "rejects a password shorter than 8 characters" do
    user = User.new(email: "new.person@example.com", password: "1234567")

    assert_not user.valid?
    assert_includes user.errors[:password], "must be at least 8 characters long."
  end

  test "requires a password" do
    user = User.new(email: "new.person@example.com", password: nil)

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "stores the password as a bcrypt digest, never in plaintext" do
    user = User.create!(email: "new.person@example.com", password: VALID_PASSWORD)

    assert_not_equal VALID_PASSWORD, user.encrypted_password
    assert user.valid_password?(VALID_PASSWORD)
  end

  # 002 FR-007: the floor is required when saving the locker profile, and only
  # then — an account with no floor yet must still be editable in every other way.
  test "requires a floor on the locker profile save path" do
    user = users(:alice)

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], "can't be blank"
  end

  test "does not require a floor outside the locker profile save path" do
    user = users(:alice)
    user.email = "alice.renamed@example.com"

    assert user.save, user.errors.full_messages.to_sentence
  end

  # 002 FR-002: having no locker is expected, so "no locker" can never collide.
  test "allows several accounts to have no locker number at once" do
    assert_nil users(:alice).locker_number
    user = users(:carol)

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # 006 FR-002: carol is on floor 2 and bob on floor 3, so bob's number names a
  # locker she is not asking for. Under 002's rule this was refused; it is the
  # case the feature exists to allow.
  test "allows the same locker number on a different floor" do
    user = users(:carol)
    user.locker_number = users(:bob).locker_number

    assert_not_equal users(:bob).floor, user.floor
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # 006 FR-003: same floor, same number — one locker, two claims.
  test "rejects a locker number another account already holds on the same floor" do
    user = users(:carol)
    user.floor = users(:bob).floor
    user.locker_number = users(:bob).locker_number

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], User::LOCKER_NUMBER_TAKEN_MESSAGE
  end

  # 006 FR-004: the holder is not a rival to themselves, so saving the form
  # untouched cannot be a collision.
  test "allows a user to resubmit their own current floor and locker number unchanged" do
    user = users(:dave)
    user.floor = user.floor
    user.locker_number = user.locker_number

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  test "stores a blank locker number as nil rather than an empty string" do
    user = users(:carol)
    user.locker_number = "   "

    assert user.save(context: :locker_profile_update)
    assert_nil user.reload.locker_number
  end

  # 006 FR-003/SC-003: the unique index — not the validation above — is what holds
  # under concurrency, so it has to reject a duplicate on its own. The floor is
  # set alongside the number because the index now spans the pair: leave carol on
  # her own floor and there is nothing for the database to refuse.
  test "the database rejects a duplicate locker number on the same floor even when validation is skipped" do
    user = users(:carol)
    user.floor = users(:bob).floor
    user.locker_number = users(:bob).locker_number

    assert_raises ActiveRecord::RecordNotUnique do
      user.save(validate: false)
    end
  end

  # 006 FR-007/FR-008: the number is scoped to a floor, so there is no floor to
  # scope it to until one is given. dave and carol are used for the moves below
  # rather than bob: bob is the recipient of alice_pending_to_bob, and 005 holds
  # a saved floor still for as long as a proposal is outstanding, which would
  # answer these tests for a reason that has nothing to do with uniqueness.
  test "rejects saving a locker number when no floor is on file or supplied" do
    user = users(:alice)
    user.locker_number = "Z99"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], "can't be blank"
  end

  # 006 FR-005: the pair is re-checked against the floor being moved to, not the
  # one being left.
  test "allows moving a locker number to a different floor when that floor's slot is free" do
    user = users(:dave)
    user.floor = "9"

    assert user.save(context: :locker_profile_update), user.errors.full_messages.to_sentence
    assert_equal [ "9", "D07" ], [ user.reload.floor, user.locker_number ]
  end

  test "rejects moving a locker number onto a floor where another user already holds that same number" do
    holder = users(:carol)
    holder.update!(floor: "9", locker_number: "D07")

    user = users(:dave)
    user.floor = "9"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], User::LOCKER_NUMBER_TAKEN_MESSAGE
  end

  # 006 FR-006: a pair is held, not owned — once its holder moves off it, it is
  # immediately someone else's to take.
  test "frees a vacated floor-and-locker pair for another user to claim" do
    mover = users(:dave)
    mover.floor = "9"

    assert mover.save(context: :locker_profile_update), mover.errors.full_messages.to_sentence

    claimant = users(:carol)
    claimant.floor = "4"
    claimant.locker_number = "D07"

    assert claimant.valid?(:locker_profile_update), claimant.errors.full_messages.to_sentence
  end

  # 005 FR-001/FR-002: while a swap is being negotiated, these two values are what
  # the other party is answering — so they are held still until it is settled.
  # bob is the recipient of alice_pending_to_bob, which every test loads.
  test "a saved floor cannot be changed while a swap proposal is active" do
    user = users(:bob)
    user.floor = "9"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], User::LOCKED_BY_SWAP_MESSAGE
  end

  test "a saved locker number cannot be changed while a swap proposal is active" do
    user = users(:bob)
    user.locker_number = "B99"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], User::LOCKED_BY_SWAP_MESSAGE
  end

  # Saving the form untouched is not a change, so there is nothing to hold still.
  test "resubmitting the same floor and locker number is allowed while locked" do
    user = users(:bob)
    user.floor = user.floor
    user.locker_number = user.locker_number

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # FR-001/FR-002 "already-saved" clarification: a requester need not have a locker
  # of their own (004), so locking the first entry would strand them — with an
  # active proposal they can never withdraw their way out of.
  test "a first-time floor and locker number can still be saved while locked" do
    user = users(:alice)
    user.floor = "5"
    user.locker_number = "C01"

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # Acceptance Scenario 3: an accepted exchange holds the values just as a pending
  # proposal does — this is the point where they are about to be swapped for real.
  test "a saved floor cannot be changed while an exchange is in progress" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)

    requester = users(:dave)
    requester.floor = "9"
    recipient = users(:carol)
    recipient.floor = "9"

    assert_not requester.valid?(:locker_profile_update)
    assert_not recipient.valid?(:locker_profile_update)
  end

  # Acceptance Scenario 5: the hold lasts exactly as long as the proposal does.
  test "the floor can be changed again once the proposal is resolved" do
    locker_swap_proposals(:alice_pending_to_bob).decline!

    user = users(:bob)
    user.floor = "9"

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # --- 013: the administrator -----------------------------------------------

  # FR-001: on an instance nobody has registered on yet, the first account to be
  # created is the administrator, with no setup step by anyone.
  #
  # destroy_all rather than delete_all: the fixtures hang wishes and proposals off
  # these rows, and the foreign keys would refuse a bare delete. The empty site is
  # the precondition the requirement is written about, so it has to be built here
  # rather than assumed — every test in this file starts with six accounts loaded.
  test "the first account ever created is the administrator" do
    User.destroy_all

    first = User.create!(email: "first@example.com", password: VALID_PASSWORD)

    assert_predicate first, :admin?
  end

  # FR-002: the flag is claimed once, by the first account, and no later signup
  # is a candidate for it however many accounts come and go afterwards.
  test "an account created after the first is not an administrator" do
    User.destroy_all
    User.create!(email: "first@example.com", password: VALID_PASSWORD)

    second = User.create!(email: "second@example.com", password: VALID_PASSWORD)

    assert_not_predicate second, :admin?
  end

  # 029 FR-002/FR-003: the super admin role is exactly the first account's
  # bootstrap-administrator status, named — so it follows the same rule as
  # :admin? above, one for one.
  test "the first account ever created is the super admin" do
    User.destroy_all

    first = User.create!(email: "first@example.com", password: VALID_PASSWORD)

    assert_predicate first, :super_admin?
  end

  test "an account created after the first is not the super admin" do
    User.destroy_all
    User.create!(email: "first@example.com", password: VALID_PASSWORD)

    second = User.create!(email: "second@example.com", password: VALID_PASSWORD)

    assert_not_predicate second, :super_admin?
  end

  # 029 FR-013: the existing bootstrap-administrator fixture already satisfies
  # super_admin? with no code path executed beyond the predicate itself — fixture
  # data, not a runtime registration — which is what makes the retroactive
  # promotion automatic rather than a migration (data-model.md, research.md R1).
  test "the existing bootstrap administrator fixture is already the super admin" do
    assert_predicate users(:frank), :super_admin?
  end

  test "a granted administrator fixture is not the super admin" do
    assert_not_predicate users(:grace), :super_admin?
  end

  # The ordinary case on a site that is already running: signing up today makes
  # nobody an administrator, whatever the fixtures happen to contain.
  #
  # 015 FR-013: the second assertion used to read find_by(admin: true) and expect
  # frank. With more than one administrator possible that question no longer has a
  # single answer, so it asks what it actually meant — the set did not change.
  test "signing up on a site that already has accounts grants nothing" do
    administrators_before = User.where(admin: true).order(:id).to_a

    user = User.create!(email: "newcomer@example.com", password: VALID_PASSWORD)

    assert_not_predicate user, :admin?
    assert_equal administrators_before, User.where(admin: true).order(:id).to_a
  end

  # FR-002/SC-002: the callback reads the table before the insert, so it cannot be
  # what guarantees a single administrator under concurrency — the index is. This
  # asserts the index on its own, going around the callback with insert_all! the
  # way the locker-number test goes around its validation.
  test "the database refuses a second administrator" do
    assert_raises ActiveRecord::RecordNotUnique do
      User.insert_all!([ {
        email: "rival@example.com",
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        admin: true, created_at: Time.current, updated_at: Time.current
      } ])
    end
  end

  # FR-002, research.md R2: two signups on an empty site can both read it as
  # empty and both come to the insert claiming the flag. The one that gets there
  # second must still end up with an account — losing a race is not a signup
  # failure — just without the flag. Never both, and never neither.
  test "a signup that loses the race to claim the flag is still saved, without it" do
    User.destroy_all

    loser = User.new(email: "loser@example.com", password: VALID_PASSWORD)
    with_a_rival_claiming_the_flag_mid_save(email: "winner@example.com") do
      assert loser.save, loser.errors.full_messages.to_sentence
    end

    assert_not_predicate loser.reload, :admin?
    assert_equal 1, User.where(admin: true).count
    assert_equal "winner@example.com", User.find_by(admin: true).email
  end

  # 013 FR-011 said deleting the administrator left the site with none, and these
  # two tests asserted exactly that. 015 FR-016 supersedes it: that outcome is no
  # longer reachable while other accounts are registered, because the deletion is
  # refused (see the guard tests below). What survives from 013 is the half that
  # still holds — the flag does not move to a successor.
  # 029: frank may not go here — he is the super admin, and other accounts
  # (grace among them) remain, so his own destroy is refused (see the
  # super-admin-specific guard tests below). grace holds rights too, and is not
  # the super admin, so she may go freely; nobody is promoted to fill the slot
  # she vacates.
  test "deleting an administrator does not promote anyone in their place" do
    administrators_before = User.where(admin: true).order(:id).to_a

    users(:grace).destroy

    assert_equal administrators_before - [ users(:grace) ], User.where(admin: true).order(:id).to_a
  end

  # The same rule seen from the other side: an administrator slot is not an opening
  # that the next person to sign up walks into. 013 tested this by deleting the only
  # administrator first, which FR-016 refused; 029 refuses it even more strongly for
  # the super admin specifically, so the vacancy is staged by deleting the granted
  # administrator (grace) instead.
  test "signing up while the site has an administrator grants nothing" do
    users(:grace).destroy

    newcomer = User.create!(email: "newcomer@example.com", password: VALID_PASSWORD)

    assert_not_predicate newcomer, :admin?
    assert_equal [ users(:frank) ], User.where(admin: true).to_a
  end

  # 015, research.md R1: the retry in User#save identifies the bootstrap-race
  # conflict by matching the error message, and that message names either the
  # column or the index depending on the adapter. SQLite names the column
  # ("UNIQUE constraint failed: users.admin"), so the race test above keeps
  # passing here whether or not the index branch of the pattern was updated —
  # which is exactly why the index branch needs a test of its own. Without this,
  # renaming the index leaves a dead branch nothing would notice until the
  # adapter changed.
  test "the bootstrap-race pattern recognises the renamed index by name" do
    assert_match User::ADMINISTRATOR_INDEX_CONFLICT,
                 "PG::UniqueViolation: duplicate key value violates unique constraint " \
                 "\"index_users_on_bootstrap_admin\""
    assert_no_match User::ADMINISTRATOR_INDEX_CONFLICT,
                    "PG::UniqueViolation: duplicate key value violates unique constraint " \
                    "\"index_users_on_email\""
  end

  # 015 FR-013: the cap is gone. Two administrators may hold the rights at once,
  # provided only one of them claimed them at first registration.
  test "a granted administrator may exist alongside the bootstrap administrator" do
    assert_predicate users(:frank), :admin?
    assert_predicate users(:grace), :admin?
    assert_nil users(:frank).admin_granted_at
    assert_not_nil users(:grace).admin_granted_at
  end

  # FR-013: and there is no limit — a third, a fourth, as many as are granted.
  test "any number of granted administrators may exist at once" do
    User.insert_all!([ :heidi, :ivan ].map do |name|
      {
        email: "#{name}@example.com",
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        admin: true, admin_granted_at: Time.current, admin_granted_by_id: users(:frank).id,
        created_at: Time.current, updated_at: Time.current
      }
    end)

    assert_equal 4, User.where(admin: true).count
  end

  # 013 FR-002 kept: the bootstrap slot is still unique. This is the same assertion
  # the index has always made, now scoped to rows that claimed the rights rather
  # than being given them — the reason a granted administrator is not a collision.
  test "the database still refuses a second bootstrap administrator" do
    assert_raises ActiveRecord::RecordNotUnique do
      User.insert_all!([ {
        email: "rival@example.com",
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        admin: true, created_at: Time.current, updated_at: Time.current
      } ])
    end
  end

  # 015 FR-006, FR-017: the grant writes all three facts at once — the flag, when
  # it happened, and who did it. A row carrying the flag without the provenance
  # would be indistinguishable from the bootstrap administrator, and would land in
  # the bootstrap index besides.
  test "granting rights records the flag, the moment and the grantor together" do
    granted_at = nil

    assert_changes -> { users(:carol).reload.admin? }, from: false, to: true do
      granted_at = Time.current
      users(:carol).grant_admin_rights!(by: users(:frank))
    end

    carol = users(:carol).reload
    assert_equal users(:frank), carol.admin_granted_by
    assert_in_delta granted_at, carol.admin_granted_at, 5
  end

  # FR-012: granting to an account that already has the rights is not a failure and
  # not a second grant. The recorded origin stays the first one, so a stale list
  # cannot rewrite history by being clicked twice.
  test "granting rights again leaves the original origin untouched" do
    original_at = users(:grace).admin_granted_at

    users(:grace).grant_admin_rights!(by: users(:carol))

    grace = users(:grace).reload
    assert_predicate grace, :admin?
    assert_equal original_at, grace.admin_granted_at
    assert_equal users(:frank), grace.admin_granted_by
  end

  # FR-013: the grantor keeps what they gave away.
  test "granting rights leaves the granting administrator an administrator" do
    users(:carol).grant_admin_rights!(by: users(:frank))

    assert_predicate users(:frank).reload, :admin?
  end

  # 029 FR-001: granted rights are never super admin rights — admin_granted_at is
  # always stamped by grant_admin_rights!, which is exactly what keeps a granted
  # account out of super_admin?'s definition.
  test "granting rights never makes the recipient the super admin" do
    users(:carol).grant_admin_rights!(by: users(:frank))

    assert_not_predicate users(:carol).reload, :super_admin?
  end

  # --- 028 FR-009, FR-018: revoking ---------------------------------------------

  # The direct counterpart of "granting rights records the flag, the moment and
  # the grantor together" above — one write clears all three at once, so no
  # trace of the prior grant survives a revoke.
  test "revoking rights clears the flag and every trace of the grant" do
    assert_changes -> { users(:grace).reload.admin? }, from: true, to: false do
      users(:grace).revoke_admin_rights!
    end

    grace = users(:grace).reload
    assert_nil grace.admin_granted_at
    assert_nil grace.admin_granted_by
  end

  # FR-014: revoking rights from an account that does not have them is not a
  # failure and not a second revoke — mirrors "granting rights again leaves the
  # original origin untouched" above, for the opposite direction.
  test "revoking rights from a standard account is a no-op, not a failure" do
    assert_no_changes -> { users(:carol).reload.admin? } do
      users(:carol).revoke_admin_rights!
    end

    assert_not_predicate users(:carol).reload, :admin?
  end

  # FR-016: revoking one account's rights must not touch any other account.
  test "revoking one account's rights leaves every other account's rights untouched" do
    users(:grace).revoke_admin_rights!

    assert_predicate users(:frank).reload, :admin?
    assert_not_predicate users(:carol).reload, :admin?
  end

  # Edge Cases (spec.md), Assumptions, quickstart.md Scenario 2 steps 7-8: the
  # clear-then-regrant cycle actually resets provenance rather than merely
  # appearing to — grace's original grant was by frank; revoking and granting
  # again by a different administrator must leave no trace of the original.
  test "granting rights again after a revoke starts a fresh record" do
    original_at = users(:grace).admin_granted_at
    original_by = users(:grace).admin_granted_by

    users(:grace).revoke_admin_rights!
    regranted_at = Time.current
    users(:grace).grant_admin_rights!(by: users(:carol))

    grace = users(:grace).reload
    assert_predicate grace, :admin?
    assert_equal users(:carol), grace.admin_granted_by
    assert_not_equal original_by, grace.admin_granted_by
    assert_in_delta regranted_at, grace.admin_granted_at, 5
    assert_not_equal original_at, grace.admin_granted_at
  end

  # FR-019: the grant outlives the account that made it. dependent: :nullify is
  # what holds this — with :destroy, deleting an administrator would delete
  # everyone they had ever promoted.
  #
  # 029: the grantor destroyed here has to be an account whose own destroy is
  # never restricted, so this uses grace (a granted administrator) as the
  # grantor rather than frank (the super admin, who cannot be destroyed while
  # carol/others remain) — the dependent: :nullify behavior under test does not
  # depend on which admin triggers it.
  test "deleting the grantor keeps the grant and clears only the grantor" do
    users(:carol).grant_admin_rights!(by: users(:grace))
    granted_at = users(:carol).reload.admin_granted_at

    users(:grace).destroy

    carol = users(:carol).reload
    assert_predicate carol, :admin?
    assert_equal granted_at, carol.admin_granted_at
    assert_nil carol.admin_granted_by
  end

  # --- 029 FR-010/FR-014: the super admin cannot walk out while anyone remains -
  #
  # 015 FR-016 originally guarded this for whichever account was the site's only
  # administrator. 029 replaces that rule outright (research.md R6): the super
  # admin's own account may never be cancelled while any other account exists —
  # admin or not — and, as a direct consequence, a granted (non-super)
  # administrator's own account is never restricted at all, because the super
  # admin's permanence already guarantees the site keeps an administrator.

  # The strict case: another administrator (grace) is still present, not just
  # some non-admin accounts — the super admin is refused all the same, which is
  # what "regardless of how many other admins exist" (FR-010) actually means.
  test "the super admin cannot be deleted while any other account remains, admin or not" do
    assert_no_difference -> { User.count } do
      assert_not users(:frank).destroy
    end

    assert_predicate users(:frank).reload, :super_admin?
    assert_includes users(:frank).errors[:base], I18n.t("user.messages.super_admin_uncancellable")
  end

  # The case 015 FR-016 originally covered — no other admin remains — is still
  # refused, just by the new, stricter rule rather than the retired one.
  test "the super admin cannot be deleted even when every other admin has been removed, as long as a non-admin account remains" do
    users(:grace).destroy

    assert_no_difference -> { User.count } do
      assert_not users(:frank).destroy
    end

    assert_predicate users(:frank).reload, :super_admin?
  end

  # 029 FR-014: the direct consequence of the super admin's own permanence — a
  # granted administrator's own account is never restricted, however many other
  # admins remain (frank, here, always does).
  test "a granted administrator can be deleted while the super admin remains" do
    assert_difference -> { User.count }, -1 do
      assert users(:grace).destroy
    end
  end

  test "a non-administrator can always be deleted" do
    assert_difference -> { User.count }, -1 do
      assert users(:carol).destroy
    end
  end

  # The refusal has to say what to do about it, not merely refuse — and the
  # remedy the old message offered ("grant rights to someone else") no longer
  # applies, since granting rights elsewhere does not let the super admin leave.
  test "the refused super admin is told the account can never be cancelled" do
    users(:grace).destroy

    users(:frank).destroy

    assert_includes users(:frank).errors[:base], I18n.t("user.messages.super_admin_uncancellable")
  end

  # The one exception FR-010 preserves (research.md R6, spec.md Clarifications):
  # the sole account on the site — the super admin by definition — can still
  # cancel. With nothing left to administer there is nobody to lock out, and the
  # next person to register claims the rights exactly as the first one did (013
  # FR-001), including the super admin role itself.
  test "the sole account on the site can be deleted even though it is the super admin" do
    # Staged through the real destroy path rather than delete_all: the wishes and
    # swap proposals hanging off these accounts have foreign keys back to them,
    # and Rails declares SQLite's as deferrable, so delete_all leaves orphans that
    # only surface as a violation later — inside the very destroy under test.
    users(:grace).destroy                  # allowed: she is not the super admin
    User.where(admin: false).destroy_all   # never guarded

    assert_equal [ users(:frank) ], User.all.to_a

    assert_difference -> { User.count }, -1 do
      assert users(:frank).destroy
    end

    successor = User.create!(email: "next@example.com", password: VALID_PASSWORD)
    assert_predicate successor, :admin?
    assert_predicate successor, :super_admin?
  end

  # --- 016: the allowed email domains gate -----------------------------------
  #
  # No fixture configures a domain (research.md R5), so the table is empty in
  # every test that does not say otherwise — which is the site's own default and
  # the reason every other signup test in the suite is unaffected by this feature.

  # FR-004: nothing configured, nothing restricted. This is the state the site
  # ships in and the state it returns to when the last domain is removed.
  test "with no domain configured, any email domain may register" do
    [ "anyone@wherever.example", "someone@another.test" ].each do |email|
      assert_predicate User.new(email: email, password: VALID_PASSWORD), :valid?
    end
  end

  # FR-005: the whole point of the feature.
  test "with a domain configured, an email on another domain is refused" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    user = User.new(email: "person@other.example", password: VALID_PASSWORD)

    assert_not_predicate user, :valid?
  end

  # FR-006: the exact sentence, on :base rather than on :email — full_messages
  # prefixes an attribute-scoped message with the attribute name, and the spec
  # requires this text and no other (research.md R2). A test that matched loosely
  # would let "Email Your email address domain is not allowed" through.
  test "the refusal is the exact message the spec requires" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    user = User.new(email: "person@other.example", password: VALID_PASSWORD)
    user.validate

    assert_equal [ "Your email address domain is not allowed" ], user.errors[:base]
    assert_includes user.errors.full_messages, "Your email address domain is not allowed"
  end

  test "with a domain configured, an email on that domain may register" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    assert_predicate User.new(email: "person@allowed.example", password: VALID_PASSWORD), :valid?
  end

  # FR-005: any one of them, not the first one.
  test "an email matching any configured domain may register" do
    %w[first.example second.example third.example].each { |d| AllowedEmailDomain.create!(domain: d) }

    assert_predicate User.new(email: "person@second.example", password: VALID_PASSWORD), :valid?
    assert_not_predicate User.new(email: "person@fourth.example", password: VALID_PASSWORD), :valid?
  end

  # FR-007: case-insensitive, from either side — the configured domain is
  # normalized on the way in, and the submitted address is folded on the way
  # through, so neither spelling decides the answer.
  test "the match ignores casing on both sides" do
    AllowedEmailDomain.create!(domain: "Allowed.Example")

    [ "person@allowed.example", "person@Allowed.Example", "person@ALLOWED.EXAMPLE" ].each do |email|
      assert_predicate User.new(email: email, password: VALID_PASSWORD), :valid?, email
    end
  end

  # FR-007, Clarifications 2026-09-18: exact match only. "company.com" admits
  # company.com and nothing else — a look-alike like evilallowed.example is the
  # reason this is a comparison and not a suffix test.
  test "a subdomain of an allowed domain is refused unless listed itself" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    assert_not_predicate User.new(email: "person@mail.allowed.example", password: VALID_PASSWORD), :valid?
    assert_not_predicate User.new(email: "person@evilallowed.example", password: VALID_PASSWORD), :valid?

    AllowedEmailDomain.create!(domain: "mail.allowed.example")

    assert_predicate User.new(email: "person@mail.allowed.example", password: VALID_PASSWORD), :valid?
  end

  # FR-010: the restriction gates registration and nothing else. Scoped on:
  # :create, so an account that already exists is never re-judged — which is what
  # keeps a newly configured allow-list from locking out the people already here,
  # through Devise's own account update, a password reset, or anything else that
  # saves an existing row.
  test "an existing account on a now-disallowed domain still saves" do
    existing = users(:carol)
    AllowedEmailDomain.create!(domain: "allowed.example")

    assert_not_equal "allowed.example", existing.email.split("@").last

    existing.floor = "9"

    assert existing.save, existing.errors.full_messages.to_sentence
  end

  test "an existing account on a now-disallowed domain can still change its password" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    assert users(:carol).update(password: "newpassword123", password_confirmation: "newpassword123")
  end

  # An address with no "@" is Devise's refusal to make, not this validation's —
  # but it must not blow up on the way past, and it must not be let through on a
  # site that has an allow-list.
  test "a malformed address is refused rather than raising" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    user = User.new(email: "no-at-sign", password: VALID_PASSWORD)

    assert_nothing_raised { user.validate }
    assert_not_predicate user, :valid?
  end

  # --- 020: the admin Users screen's four filters ----------------------------

  test "with_role matches administrators and standard accounts case-insensitively" do
    assert_includes User.with_role("admin"), users(:frank)
    assert_not_includes User.with_role("admin"), users(:carol)

    assert_includes User.with_role("standard"), users(:carol)
    assert_not_includes User.with_role("standard"), users(:frank)

    # research.md R4/F1: RoleFilter sends the capitalized display value as the
    # filter's own query value, so the scope has to accept it too.
    assert_includes User.with_role("Admin"), users(:frank)
    assert_includes User.with_role("STANDARD"), users(:carol)
  end

  test "with_role applies no restriction for a blank or unrecognized value" do
    [ nil, "", "   ", "superuser" ].each do |value|
      assert_equal User.count, User.with_role(value).count, "#{value.inspect} should not filter"
    end
  end

  test "on_floor matches a floor exactly" do
    assert_includes User.on_floor(users(:bob).floor), users(:bob)
    assert_not_includes User.on_floor(users(:bob).floor), users(:carol)
  end

  test "on_floor applies no restriction when blank" do
    assert_equal User.count, User.on_floor(nil).count
    assert_equal User.count, User.on_floor("").count
  end

  test "with_locker_number matches a locker number exactly, not a substring" do
    assert_includes User.with_locker_number(users(:bob).locker_number), users(:bob)

    # FR-007: the clarified exact-match decision — a shorter locker number
    # elsewhere on file must not match "B12" by substring.
    User.insert_all!([ {
      email: "shortlocker@example.com",
      encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
      floor: "3", locker_number: "1", created_at: Time.current, updated_at: Time.current
    } ])

    assert_not_includes User.with_locker_number("1").map(&:email), users(:bob).email
  end

  test "with_locker_number applies no restriction when blank" do
    assert_equal User.count, User.with_locker_number(nil).count
  end

  test "email_containing matches any account whose email contains the text, case-insensitively" do
    assert_includes User.email_containing("quinn"), users(:quinn)
    assert_includes User.email_containing("QUINN"), users(:quinn)
    assert_includes User.email_containing("quinn_search"), users(:quinn)
  end

  # research.md R4/C1: a literal "%"/"_" in the search text must be matched
  # literally, not act as a SQL wildcard that would also match every other email.
  test "email_containing treats a literal underscore as a literal character" do
    matches = User.email_containing("n_s")

    assert_includes matches, users(:quinn)
    assert_equal 1, matches.count, "an unescaped '_' would also match e.g. \"ana#{"s"}\" via the wildcard"
  end

  test "email_containing applies no restriction when blank" do
    assert_equal User.count, User.email_containing(nil).count
  end

  test "saved_floors returns every distinct floor saved by any registered user" do
    assert_equal User.where.not(floor: [ nil, "" ]).distinct.pluck(:floor).sort, User.saved_floors.sort
    assert_includes User.saved_floors, users(:bob).floor
    assert_not_includes User.saved_floors, nil
  end

  # --- 027 FR-009a: who last edited this account's floor/locker on its behalf -

  test "locker_edited_by and locker_edited_at persist together" do
    edited_at = Time.current
    users(:carol).update!(locker_edited_by: users(:frank), locker_edited_at: edited_at)

    carol = users(:carol).reload
    assert_equal users(:frank), carol.locker_edited_by
    assert_in_delta edited_at, carol.locker_edited_at, 1
  end

  # dependent: :nullify is what holds this — with :destroy, deleting an
  # administrator would delete every account they had ever edited on behalf of.
  # 029: the editor destroyed here has to be an account whose own destroy is
  # never restricted, so this uses grace (a granted administrator) rather than
  # frank (the super admin, who cannot be destroyed while carol/others remain) —
  # the dependent: :nullify behavior under test does not depend on which admin
  # triggers it.
  test "deleting the editor keeps the edit provenance and clears only the editor" do
    users(:carol).update!(locker_edited_by: users(:grace), locker_edited_at: Time.current)
    edited_at = users(:carol).reload.locker_edited_at

    users(:grace).destroy

    carol = users(:carol).reload
    assert_equal edited_at, carol.locker_edited_at
    assert_nil carol.locker_edited_by
  end

  # --- 027 FR-011a: who last cancelled this account's search on its behalf ----

  test "search_cancelled_by and search_cancelled_at persist together" do
    cancelled_at = Time.current
    users(:carol).update!(search_cancelled_by: users(:frank), search_cancelled_at: cancelled_at)

    carol = users(:carol).reload
    assert_equal users(:frank), carol.search_cancelled_by
    assert_in_delta cancelled_at, carol.search_cancelled_at, 1
  end

  # 029: same reason as the editor test above — grace, not frank, is the one
  # whose destroy is never restricted.
  test "deleting the canceller keeps the cancellation provenance and clears only the canceller" do
    users(:carol).update!(search_cancelled_by: users(:grace), search_cancelled_at: Time.current)
    cancelled_at = users(:carol).reload.search_cancelled_at

    users(:grace).destroy

    carol = users(:carol).reload
    assert_equal cancelled_at, carol.search_cancelled_at
    assert_nil carol.search_cancelled_by
  end

  private

    # Stages the state the rescue exists for: another signup has already taken the
    # flag and committed, while this record is still carrying its own claim to it.
    #
    # The winner is written first, and outside the save. Inserting it from inside
    # the loser's save — which is where it lands in wall-clock terms — does not
    # survive: the rejected INSERT rolls that transaction back and takes the
    # winner with it, so the retry finds an empty table and claims the flag after
    # all. In a real race the winner is committed on its own connection and no
    # rollback of the loser's touches it, which is what writing it here reproduces.
    #
    # The lambda then puts the claim back once, standing in for the loser having
    # read the site as empty a moment before the winner committed. Once only: on
    # the retry the callback's own answer is what must stand, and that is the
    # behaviour under test.
    #
    # insert_all! so the winner skips callbacks — through create! it would read
    # the site as empty too and stage a different situation. No mocking gem is
    # bundled (see Gemfile), so this is hand-rolled, as the comparable stub in
    # locker_wishes_controller_test is.
    def with_a_rival_claiming_the_flag_mid_save(email:)
      User.insert_all!([ {
        email: email,
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        admin: true, created_at: Time.current, updated_at: Time.current
      } ])

      claimed = false
      still_claiming = lambda do
        next if claimed

        claimed = true
        self.admin = true
      end

      User.set_callback(:create, :before, still_claiming)
      yield
    ensure
      User.skip_callback(:create, :before, still_claiming, raise: false)
    end
  # --- 030 User Story 2: floors are a choice from the site's list -------------

  # FR-005: once a list is saved, only its floors can be chosen.
  test "a floor outside the site's list is refused on the locker profile save path" do
    SiteFloorList.current.update!(floors_text: "0, 1, 2, 3")
    user = users(:alice)

    user.floor = "7"
    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], I18n.t("errors.messages.floor_not_offered")

    user.floor = "2"
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # FR-006: before the first save the floor is free text, as it always was.
  test "any floor is accepted while no list is saved" do
    user = users(:alice)
    user.floor = "anything"

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # FR-007/FR-011: a floor removed from the list stays on file and can be saved
  # again unchanged — only a change has to land on a listed floor.
  test "a saved floor no longer listed is kept when left unchanged, refused when changed to another unlisted one" do
    SiteFloorList.current.update!(floors_text: "0, 1, 2")
    user = users(:carol)
    user.update_columns(floor: "5")

    user.floor = "5"
    user.locker_number = "C77"
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence

    user.floor = "6"
    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], I18n.t("errors.messages.floor_not_offered")
  end

  # The rule belongs to the locker profile save path only, like the presence rule
  # beside it: Devise's own account update must not trip over a legacy floor.
  test "the floor list does not apply outside the locker profile save path" do
    SiteFloorList.current.update!(floors_text: "0, 1")
    user = users(:carol)
    user.email = "carol.renamed@example.com"

    assert user.save, user.errors.full_messages.to_sentence
  end
  # --- 030 User Story 4: locker numbers follow the site's format --------------

  test "a locker number that does not match the format is refused on the locker profile save path" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    user = users(:carol)

    user.locker_number = "42"
    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number],
                    I18n.t("errors.messages.locker_number_format_mismatch", expected: "\\d{3}")

    user.locker_number = "042"
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # FR-014: the spaces are ignored for the check *and* gone from what is saved,
  # so the stored number is the one uniqueness compares (006).
  test "surrounding spaces are stripped before the number is checked and saved" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    user = users(:carol)
    user.locker_number = " 042 "

    assert_equal "042", user.locker_number
    assert user.save(context: :locker_profile_update), user.errors.full_messages.to_sentence

    rival = users(:alice)
    rival.floor = user.floor
    rival.locker_number = "  042"
    assert_not rival.valid?(:locker_profile_update)
    assert_includes rival.errors[:locker_number], User::LOCKER_NUMBER_TAKEN_MESSAGE
  end

  # FR-015: "no locker" stays a valid answer whatever the format.
  test "no locker number is accepted whatever the format" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    user = users(:carol)
    user.locker_number = "   "

    assert_nil user.locker_number
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # FR-017: a number on file from before the format is kept while it is left
  # alone — here only the floor moves — and refused once it is changed to
  # another number that does not match.
  test "a legacy number is kept while unchanged and refused once changed to another that does not match" do
    user = users(:bob)
    user.update_columns(locker_number: "42")
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    LockerSwapProposal.where(requester: user).or(LockerSwapProposal.where(recipient: user)).delete_all

    user.floor = "8"
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence

    user.locker_number = "43"
    assert_not user.valid?(:locker_profile_update)
  end

  # FR-021: history keeps what was recorded at the time, whatever the site's
  # floors and format become afterwards.
  test "changing the floor list and the format leaves resolved proposals as recorded" do
    proposal = locker_swap_proposals(:dave_declined_to_carol)
    recorded = proposal.attributes.slice(*proposal.attributes.keys.grep(/_at_resolution\z/))

    SiteFloorList.current.update!(floors_text: "RDC")
    LockerNumberFormat.current.update!(pattern: "Z\\d")

    assert_equal recorded, proposal.reload.attributes.slice(*recorded.keys)
  end
  # --- 031 User Story 2: locker numbers must be known to the Locker Map ------

  test "an undeclared floor + locker number pair is refused, a declared one is accepted" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    user = users(:alice)

    user.floor = "2"
    user.locker_number = "999"
    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], I18n.t("errors.messages.locker_number_unknown")

    user.locker_number = "203"
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # FR-013: a pair already on file keeps validating when nothing about it is
  # moving, even once the map is in active use elsewhere — the grandfather
  # rule. (Declaring an unrelated entry makes the map non-empty, so this
  # exercises the "unchanged" skip itself, not merely FR-013a's permissive
  # empty-map baseline.)
  test "an already-saved pair stays valid when left unchanged, whatever else changes" do
    Zone.create!(floor: "9", name: "Elsewhere").locker_map_entries.create!(locker_number: "1")
    user = users(:carol)
    user.update_columns(floor: "2", locker_number: "201")

    user.floor = "2"
    user.locker_number = "201"
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence

    user.email = "carol.renamed@example.com"
    assert user.save, user.errors.full_messages.to_sentence
  end

  # US2 acceptance scenario 4, research.md R3: the pair, not either half
  # alone, is what has to be known — changing only the floor while the
  # locker-number text stays the same still re-checks the pair.
  test "changing only the floor re-checks the pair, even though the locker number text is unchanged" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    user = users(:carol)
    user.update_columns(floor: "2", locker_number: "203")

    user.floor = "3"
    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], I18n.t("errors.messages.locker_number_unknown")
  end

  test "changing only the locker number re-checks the pair, even though the floor is unchanged" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    user = users(:carol)
    user.update_columns(floor: "2", locker_number: "203")

    user.locker_number = "999"
    assert_not user.valid?(:locker_profile_update)
  end

  # FR-013a, research.md R8: the map's own "not configured" baseline — every
  # pair is accepted while nothing has ever been declared anywhere on the
  # site, exactly as before this feature existed. Found during implementation:
  # a strict empty-map reading broke every pre-existing save path.
  test "with nothing declared in the map at all, any locker number is accepted" do
    user = users(:alice)

    user.floor = "2"
    user.locker_number = "999"
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence

    user.locker_number = "   "
    assert_nil user.locker_number
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  test "the known-locker rule does not apply outside the locker profile save path" do
    user = users(:carol)
    user.update_columns(floor: "2", locker_number: "999")
    user.email = "carol.again@example.com"

    assert user.save, user.errors.full_messages.to_sentence
  end
end
