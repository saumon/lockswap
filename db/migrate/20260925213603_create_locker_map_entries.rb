class CreateLockerMapEntries < ActiveRecord::Migration[8.1]
  def change
    # 031 FR-007/FR-012, research.md R6: the site's authoritative "known
    # locker" registry. `floor` is denormalized from the parent zone (copied
    # once, at creation, and never reassigned — a zone's own floor cannot
    # change either) purely so this table can carry the same real,
    # race-safe unique (floor, locker_number) index `users` already has (006)
    # — the guarantee behind FR-007/FR-012, not just the model-level
    # uniqueness validator.
    create_table :locker_map_entries do |t|
      t.references :zone, null: false, foreign_key: true
      t.string :floor, null: false
      t.string :locker_number, null: false

      t.timestamps
    end

    add_index :locker_map_entries, [ :floor, :locker_number ], unique: true
  end
end
