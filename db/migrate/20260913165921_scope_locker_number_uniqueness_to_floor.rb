class ScopeLockerNumberUniquenessToFloor < ActiveRecord::Migration[8.1]
  def change
    # 006 FR-001: a locker number names a locker on a floor, not in the building,
    # so the same number on two floors is two lockers. The key that has to be
    # unique is the pair. NULLs stay distinct under the composite index just as
    # they were under the single-column one, so "no locker" still never collides.
    remove_index :users, :locker_number, unique: true
    add_index :users, [ :floor, :locker_number ], unique: true
  end
end
