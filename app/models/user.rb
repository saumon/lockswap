class User < ApplicationRecord
  # :database_authenticatable — bcrypt password storage + email/password login (FR-004, FR-006)
  # :registerable            — self-service signup (FR-001, FR-003)
  # :rememberable            — persistent session across browser restarts, 30 days (FR-007)
  # :lockable                — lock after 5 consecutive failures for 15 minutes (FR-011)
  # :validatable             — email format/uniqueness and the 8-character password minimum (FR-002)
  devise :database_authenticatable, :registerable,
         :rememberable, :lockable, :validatable

  # 003: the locker this user is looking for, once they have declared a wish.
  # A wish cannot outlive the account that declared it.
  has_one :locker_wish, dependent: :destroy

  # 004: the two sides of a swap proposal. Both foreign keys point back here, so
  # each association has to name its own; neither can outlive the account.
  has_many :sent_swap_proposals, class_name: "LockerSwapProposal",
           foreign_key: :requester_id, dependent: :destroy, inverse_of: :requester
  has_many :received_swap_proposals, class_name: "LockerSwapProposal",
           foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient

  # 015 FR-017: who granted this account its administrator rights, when they were
  # granted. Self-referential, so both sides have to name the foreign key.
  #
  # :nullify and not :destroy — FR-019 asks that a grant outlive the account that
  # made it. Cascading here would delete every account an outgoing administrator
  # had ever promoted, which is the opposite of what the requirement wants, and a
  # quiet way to empty a site.
  belongs_to :admin_granted_by, class_name: "User", optional: true,
             inverse_of: :admin_grants_made
  has_many :admin_grants_made, class_name: "User", foreign_key: :admin_granted_by_id,
           dependent: :nullify, inverse_of: :admin_granted_by

  # 027 FR-009a/FR-011a: who (which administrator) last edited this account's
  # floor/locker, or last cancelled its search, on its behalf from the admin
  # detail screen — and the has_many inverse each needs so that admin's own
  # account being later cancelled nullifies the reference instead of raising a
  # foreign-key violation, the same pairing admin_granted_by/admin_grants_made
  # already establishes above.
  belongs_to :locker_edited_by, class_name: "User", optional: true,
             inverse_of: :locker_edits_made
  has_many :locker_edits_made, class_name: "User", foreign_key: :locker_edited_by_id,
           dependent: :nullify, inverse_of: :locker_edited_by

  belongs_to :search_cancelled_by, class_name: "User", optional: true,
             inverse_of: :search_cancellations_made
  has_many :search_cancellations_made, class_name: "User", foreign_key: :search_cancelled_by_id,
           dependent: :nullify, inverse_of: :search_cancelled_by

  # "No locker" must reach the database as NULL, never "": a unique index treats
  # NULLs as distinct, but two empty strings would collide (002 FR-002, FR-011).
  normalizes :locker_number, with: ->(value) { value.blank? ? nil : value }

  # 013 FR-001: the first account ever registered is the site's administrator.
  # Assigned here rather than derived on read, because a derived answer would move
  # to the next-oldest account the moment this one was deleted — which FR-011
  # forbids: deleting the administrator leaves the site with none, not a successor.
  #
  # The assignment is unconditional rather than `= true if ...`, so this is the
  # only thing that can ever set the flag: an explicit `admin: true` passed to
  # create is overwritten here, and there is no path through Active Record that
  # mints a second administrator (FR-002).
  #
  # before_create, so an update never revisits it. exists? rather than a count —
  # the question is whether anybody is already here, not how many.
  before_create :claim_administrator_if_first

  # 013 FR-002, research.md R2: the index is what actually guarantees one
  # *bootstrap* administrator, so this is where losing to it is handled. 015
  # narrowed that index rather than dropping it: granted administrators are
  # unlimited, but only one account may still claim the flag at signup.
  #
  # Two signups on an empty site can both come out of claim_administrator_if_first
  # holding the flag; one INSERT then wins and the other is rejected. The loser
  # still signed up — losing a race is not a signup failure — so the save is
  # retried, and the callback, re-reading a table that now has the winner in it,
  # hands the retry admin: false on its own.
  #
  # Only this conflict is caught: an email or locker-number collision is a real
  # refusal with a message for the user, and must keep raising. The retry is not
  # itself rescued, so a second failure propagates rather than looping.
  #
  # save and not save!, because signup reaches this through Devise's
  # `resource.save`; nothing in the application creates an account with save!.
  def save(**options, &block)
    super
  rescue ActiveRecord::RecordNotUnique => error
    raise unless lost_the_administrator_race?(error)

    super
  end

  # Both rules are scoped to :locker_profile_update so they only apply on the
  # locker-profile save path. A blanket validation would block every other save
  # for a user who has not set a floor yet — including Devise's own account
  # update — which is not what "the floor is required" means here (002 FR-007).
  validates :floor, presence: true, on: :locker_profile_update
  # The values as they are on file. While a rejected edit is being re-displayed
  # the attributes hold the input being corrected, so anything reporting what is
  # actually saved has to read past them.
  def saved_floor = floor_in_database
  def saved_locker_number = locker_number_in_database

  # 020: the admin Users screen's four filters (FR-004). Each is a no-op when
  # left blank, so the controller composes all four unconditionally and none
  # needs a branch of its own (mirrors LockerWish's looking_for/owner_on_floor,
  # feature 017).
  #
  # Matched case-insensitively: RoleFilter sends the capitalized display values
  # "Admin"/"Standard" as the filter's own query values (the same "the value is
  # also the label" convention FloorFilter uses for floors), so this has to
  # accept exactly what that sends (research.md R4, analyze finding F1).
  scope :with_role, ->(role) {
    case role.to_s.downcase
    when "admin" then where(admin: true)
    when "standard" then where(admin: false)
    else all
    end
  }

  # Exact match, same shape as LockerWish#owner_on_floor's exact-match half, but
  # directly on User rather than through a join.
  scope :on_floor, ->(floor) { floor.presence ? where(floor: floor) : all }

  # FR-007 (clarified): exact match, not a substring — locker numbers are unique
  # identifiers, not search text.
  scope :with_locker_number, ->(number) { number.presence ? where(locker_number: number) : all }

  # FR-008: partial, case-insensitive (free, via the email column's own NOCASE
  # collation) match. sanitize_sql_like escapes a literal "%"/"_" in the search
  # text; the ESCAPE '\\' clause is what makes SQLite actually treat those
  # escaped characters as literal rather than as wildcards (research.md R4,
  # analyze finding C1).
  scope :email_containing, ->(text) {
    text.presence ? where("email LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(text)}%") : all
  }

  # FR-005: every distinct floor saved by *any* registered user — independent of
  # any filter currently applied, so setting one filter never narrows what the
  # current-floor filter itself offers (research.md R3). Feeds FloorFilter's
  # `available:` exactly as LockerWish.owner_floors does for the locker wishes
  # screen.
  def self.saved_floors = where.not(floor: [ nil, "" ]).distinct.pluck(:floor)

  # 015 FR-006, FR-017: the whole of granting. One write, so an account never
  # exists carrying the flag without the provenance that goes with it — a row in
  # that state would be indistinguishable from the bootstrap administrator, and
  # would land in the bootstrap index besides.
  #
  # The guard clause is FR-012: granting to an account that already has the rights
  # is not a failure and not a second grant. A list left open while someone else
  # promoted the same person must not rewrite when the rights were obtained, nor
  # report an error for arriving second at the same destination.
  #
  # update! and not save — the bootstrap-race rescue below is deliberately only on
  # save, and this path has no race to lose: a granted row is outside the index.
  def grant_admin_rights!(by:)
    return self if admin?

    update!(admin: true, admin_granted_at: Time.current, admin_granted_by: by)
    self
  end

  # FR-018: which of the two ways this account came by its rights, asked once here
  # rather than re-derived by every caller that needs to say it.
  def admin_rights_granted? = admin? && admin_granted_at.present?

  # 029 FR-001/FR-003: the account index_users_on_bootstrap_admin already guarantees is unique —
  # admin_granted_at is nil only for the account claim_administrator_if_first promoted, never for one
  # grant_admin_rights! promoted (research.md R1). No new column: this predicate is the existing
  # invariant, named.
  def super_admin? = admin? && admin_granted_at.nil?

  # 028 FR-009, FR-018: the whole of revoking. Symmetric with #grant_admin_rights!
  # above — one write, and it clears every trace of the grant rather than
  # replacing it with a "revoked" record (research.md R4; the Clarifications
  # session declined a revoked_by/revoked_at pair). The guard clause is FR-014's
  # mirror of FR-012 above: revoking an account that is already standard is not a
  # failure and not a second revoke.
  def revoke_admin_rights!
    return self unless admin?

    update!(admin: false, admin_granted_at: nil, admin_granted_by: nil)
    self
  end

  # Says the locker is spoken for without identifying who holds it (002 FR-011).
  # Names the floor, because that is the whole scope of the refusal: the same
  # number is free to take one floor up (006 FR-003).
  # The controller reuses it for the same conflict caught by the unique index.
  #
  # 025: kept as a plain frozen string — English, matching config/locales/en.yml
  # byte for byte — purely so existing tests that assert against this constant
  # by name keep working. The *live* validation message below is a lambda
  # calling I18n.t fresh at validation time, not this constant: a validates
  # `message:` option is evaluated once, at class-load time, so referencing this
  # constant directly there would freeze the message to whatever locale was
  # active when Rails booted, never reacting to the site language (research.md
  # R2's same reasoning, applied to a validation message instead of I18n.locale).
  LOCKER_NUMBER_TAKEN_MESSAGE =
    "is not available on that floor — another account already has this locker".freeze

  # 006 FR-001: the pair is the key. A number identifies a locker only once you
  # know the floor it is on, so the same one on two floors is two lockers.
  # allow_nil is load-bearing: the uniqueness validator does not skip nil on its
  # own, so without it the second user with no locker is rejected as a duplicate.
  validates :locker_number,
            uniqueness: { scope: :floor, message: ->(_record, _data) { I18n.t("user.messages.locker_number_taken") } },
            allow_nil: true, on: :locker_profile_update

  # 005 FR-003: says why the field is refused, so the restriction reads as a
  # state the account is in rather than as something wrong with the input.
  # 025: kept for tests; see LOCKER_NUMBER_TAKEN_MESSAGE's comment.
  LOCKED_BY_SWAP_MESSAGE = "cannot be changed while you have an active swap proposal".freeze

  # 029 FR-010/FR-014, research.md R6: replaces 015's LAST_ADMINISTRATOR_MESSAGE
  # and the "no other admin remains" rule it guarded — that rule is unreachable
  # now that the super admin's own permanence guarantees the site keeps an
  # administrator whenever any other account exists (see
  # prevent_super_admin_cancellation below). Unlike LAST_ADMINISTRATOR_MESSAGE,
  # no frozen-string constant is kept for this one: nothing needs to reference it
  # by name outside I18n — tests assert against I18n.t("user.messages.super_admin_uncancellable")
  # directly, and RegistrationsController#destroy's fallback already calls I18n.t
  # fresh rather than a constant.

  # 029 FR-010: the super admin's own account is the one exit that can never be
  # taken while anyone else is still registered — no other account could ever
  # take over the role afterward, since 013 FR-002 only ever assigns it on a
  # completely empty site. Replaces 015's keep_an_administrator_for_the_remaining_
  # accounts, which only blocked deleting the site's *last* admin: this is
  # stricter (any other account, admin or not, blocks it) and, as a direct
  # consequence, a granted administrator's own account is never restricted at
  # all (research.md R6).
  #
  # before_destroy, so the check runs inside the destroy transaction. That is what
  # makes the concurrent case safe: Active Record opens SQLite transactions with
  # default_transaction_mode: :immediate, taking the write lock at BEGIN, and
  # SQLite permits one writer at a time — so two accounts cancelling at the same
  # moment are serialized and the second one's count sees the first's deletion
  # (research.md R4, carried over from 015). No advisory lock is needed; moving
  # this check out of the transaction would remove that guarantee.
  before_destroy :prevent_super_admin_cancellation

  # 005 FR-001, FR-002: a proposal is an offer made on these exact values, so
  # neither side can move them out from under the other while one is outstanding.
  validate :locker_details_held_by_active_swap, on: :locker_profile_update

  # 016 FR-006: the spec fixes this sentence exactly, so it is added to :base and
  # not to :email — full_messages prefixes an attribute-scoped message with the
  # humanized attribute name, which would render it as "Email Your email address
  # domain is not allowed" (research.md R2). The super_admin_uncancellable
  # message prevent_super_admin_cancellation adds is on :base for the same
  # reason.
  EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE = "Your email address domain is not allowed".freeze

  # 016 FR-005: registration is gated on the administrator's allow-list.
  #
  # on: :create is what makes FR-010 true by construction rather than by a second
  # guard somebody has to remember: the rule can only fire while a row is being
  # created, so an account that already exists is never re-judged — not by a
  # password reset, not by Devise's account update, not by a locker edit. A
  # blanket validation would lock out everyone already registered the moment an
  # allow-list was configured.
  validate :email_domain_allowed, on: :create

  private

    # FR-004: an empty list is not a list of zero permitted domains, it is no
    # restriction at all — so the query's emptiness is the whole of that
    # requirement, with no "restriction enabled" flag that could disagree with it.
    #
    # FR-007: an exact comparison against the normalized column, not a suffix or
    # pattern match. A suffix test would admit evilcompany.com for company.com
    # unless carefully anchored, and the Clarifications session settled that a
    # subdomain is only allowed when listed in its own right.
    #
    # One pluck rather than an exists? per candidate: the row count here is set by
    # an administrator, not by how many people have registered, so this stays
    # bounded as the site grows (Principle IV).
    def email_domain_allowed
      allowed_domains = AllowedEmailDomain.pluck(:domain)
      return if allowed_domains.empty?
      return if allowed_domains.include?(email.to_s.split("@").last.to_s.downcase)

      errors.add(:base, I18n.t("user.messages.email_domain_not_allowed"))
    end

    # 029 FR-010/FR-014, research.md R6: replaces keep_an_administrator_for_the_remaining_accounts,
    # which this makes permanently unreachable — see the before_destroy comment above for why. Only
    # the super admin's own row is ever blocked here, and only while at least one other account still
    # exists; as the sole remaining account it may still go, the same exception 013/015 already carved
    # out for "the only account on the site."
    def prevent_super_admin_cancellation
      return unless super_admin?
      return unless User.where.not(id: id).exists?

      errors.add(:base, I18n.t("user.messages.super_admin_uncancellable"))
      throw :abort
    end

    # 013 FR-002: this runs before the row is inserted, so two signups landing
    # together can both find the site empty and both try to claim the flag. The
    # partial unique index is what actually settles that race; see #save.
    def claim_administrator_if_first
      self.admin = !User.exists?
    end

    # Was the rejected write this record's attempt to claim the administrator
    # flag, rather than a genuine collision on email or on a locker?
    #
    # Matched on the index as well as the column: SQLite names the column in the
    # message ("users.admin") and other adapters name the index, and this should
    # not quietly stop working if the database under it ever changes.
    #
    # 015 renamed the index to index_users_on_bootstrap_admin. On SQLite that
    # rename is invisible here, because the column branch matches first — which is
    # why user_test covers the index branch directly rather than through a race.
    ADMINISTRATOR_INDEX_CONFLICT = /users\.admin\b|index_users_on_bootstrap_admin/

    def lost_the_administrator_race?(error)
      admin? && error.message.match?(ADMINISTRATOR_INDEX_CONFLICT)
    end

    # Only a value already on file is held: someone who has never recorded a
    # floor or a locker number is still asked for it, since an offer cannot have
    # been made on a value that does not exist (FR-001, FR-002). The query is
    # asked only when there is a change to refuse.
    def locker_details_held_by_active_swap
      changing = { floor: floor_changed? && floor_was.present?,
                   locker_number: locker_number_changed? && locker_number_was.present? }
      return if changing.values.none?
      return unless LockerSwapProposal.active_for?(self)

      changing.each { |attribute, changed| errors.add(attribute, I18n.t("user.messages.locked_by_swap")) if changed }
    end
end
