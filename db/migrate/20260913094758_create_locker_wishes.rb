class CreateLockerWishes < ActiveRecord::Migration[8.1]
  def change
    create_table :locker_wishes do |t|
      # The unique index is the real "at most one active wish per user" guarantee
      # (003 FR-003, SC-003): two concurrent declares can both pass the
      # already-has-a-wish lookup in the controller before either one commits.
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :floor, null: false

      t.timestamps
    end
  end
end
