class CreateSiteFloorLists < ActiveRecord::Migration[8.1]
  def change
    # 030 FR-001: one row, ever — the floors the super admin offers site-wide,
    # in the order typed. NULL is "never configured" and is load-bearing: until
    # the first save every floor field stays free text (FR-006), so there is
    # deliberately no default and no seed (clarification Q2).
    create_table :site_floor_lists do |t|
      t.json :floors, null: true

      t.timestamps
    end
  end
end
