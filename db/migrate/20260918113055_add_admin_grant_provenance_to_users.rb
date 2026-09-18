class AddAdminGrantProvenanceToUsers < ActiveRecord::Migration[8.1]
  def change
    # 015 FR-017: where an administrator's rights came from, recorded on the account
    # that holds them. Two columns rather than an event log, because rights are
    # granted at most once and never removed (FR-014) — so the origin is a single
    # fact about the account, not a history.
    #
    # Nullable, and NULL is meaningful: it says these rights were not granted.
    # Either the account is not an administrator, or it claimed them at first
    # registration (013 FR-001).
    add_column :users, :admin_granted_at, :datetime

    # FR-019: the grant has to outlive its grantor, so this nullifies rather than
    # cascading when that account is deleted. The Users list then says the granting
    # account no longer exists instead of showing nothing.
    add_reference :users, :admin_granted_by, foreign_key: { to_table: :users }

    # 013 FR-002 kept, its cap removed. The old index (`WHERE admin = 1`) made a
    # second administrator impossible, which is what FR-013 lifts — but it is also
    # what settles the race between two people signing up on an empty site, which
    # nothing asked to lift. See User#save.
    #
    # Narrowing it to the bootstrap case keeps exactly that: at most one account may
    # claim the flag automatically, while granted administrators (admin_granted_at
    # set) fall outside the constraint entirely and are unlimited.
    #
    # The predicate is admin_granted_at, deliberately, and not admin_granted_by_id:
    # the "by" column nullifies when the grantor is deleted, so an index keyed on it
    # would let a granted administrator drift into the bootstrap slot the moment
    # whoever promoted them cancelled — and collide with the real first account.
    # The timestamp is never cleared (research.md R1).
    remove_index :users, name: "index_users_on_admin"
    add_index :users, :admin, unique: true,
              where: "admin = 1 AND admin_granted_at IS NULL",
              name: "index_users_on_bootstrap_admin"
  end
end
