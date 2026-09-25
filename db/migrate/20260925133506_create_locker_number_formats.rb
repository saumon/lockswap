class CreateLockerNumberFormats < ActiveRecord::Migration[8.1]
  def change
    # 030 FR-009: one row, ever — the pattern every entered locker number must
    # match in full, and the plain-language wording users are shown in its place
    # (clarification Q1). Both NULL is "no format": any value is accepted.
    create_table :locker_number_formats do |t|
      t.string :pattern, null: true
      t.string :description, null: true

      t.timestamps
    end
  end
end
