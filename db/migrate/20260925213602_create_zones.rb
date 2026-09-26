class CreateZones < ActiveRecord::Migration[8.1]
  def change
    # 031 FR-002/FR-003: a named group of lockers, fixed to one floor at
    # creation and never reassigned afterward (031 clarification). Name is
    # unique per floor (FR-004a) — the same name may be reused on a different
    # floor, so the index is compound rather than on :name alone.
    create_table :zones do |t|
      t.string :floor, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :zones, [ :floor, :name ], unique: true
  end
end
