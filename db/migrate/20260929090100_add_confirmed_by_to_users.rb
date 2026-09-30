class AddConfirmedByToUsers < ActiveRecord::Migration[8.1]
  def change
    # 034 FR-036: the administrator who activated this account by hand. Same
    # shape as admin_granted_by_id / locker_edited_by_id / search_cancelled_by_id
    # — nullable, indexed, foreign-keyed; the User side nullifies it rather than
    # cascading, so an activation outlives the administrator who made it.
    add_reference :users, :confirmed_by, foreign_key: { to_table: :users }, index: true
  end
end
