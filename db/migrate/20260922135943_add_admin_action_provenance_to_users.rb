class AddAdminActionProvenanceToUsers < ActiveRecord::Migration[8.1]
  def change
    # 027 FR-009a: who (which administrator) last edited this account's floor/locker
    # on its behalf from the admin detail screen, and when. Nullable: nil means no
    # admin has ever done so — a self-service edit by the account holder does not
    # set this (research.md R3).
    #
    # No on_delete option, same as admin_granted_by_id (015): nullify-on-delete is
    # enforced at the application level via User#locker_edits_made, not the database.
    add_reference :users, :locker_edited_by, foreign_key: { to_table: :users }
    add_column :users, :locker_edited_at, :datetime

    # FR-011a: who last cancelled this account's standing wish on its behalf, and
    # when. Lives on User rather than LockerWish because the wish row itself is
    # destroyed by the cancellation it records.
    add_reference :users, :search_cancelled_by, foreign_key: { to_table: :users }
    add_column :users, :search_cancelled_at, :datetime
  end
end
