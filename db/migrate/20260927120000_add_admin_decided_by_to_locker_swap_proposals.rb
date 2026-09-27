class AddAdminDecidedByToLockerSwapProposals < ActiveRecord::Migration[8.1]
  def change
    # 033 FR-014, research.md R5: which administrator validated or refused the
    # proposal. Same shape as users.admin_granted_by_id — nullable, indexed,
    # foreign-keyed; the User side nullifies it rather than cascading.
    add_column :locker_swap_proposals, :admin_decided_by_id, :integer
    add_index :locker_swap_proposals, :admin_decided_by_id
    add_foreign_key :locker_swap_proposals, :users, column: :admin_decided_by_id
  end
end
