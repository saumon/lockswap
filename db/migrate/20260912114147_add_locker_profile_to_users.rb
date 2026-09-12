class AddLockerProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :floor, :string
    add_column :users, :locker_number, :string
    # Multiple NULLs are distinct under a unique index, so any number of users can
    # have no locker while two users still can't share one (FR-002 + FR-011).
    add_index :users, :locker_number, unique: true
  end
end
