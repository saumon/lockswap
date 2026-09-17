class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    # 013 FR-001: which account is the administrator is a fact stored on the row,
    # not one derived from "whoever is oldest right now". A derived answer would
    # silently move to the next account the moment the administrator's own row was
    # deleted, which is precisely what FR-011 forbids.
    add_column :users, :admin, :boolean, null: false, default: false

    # 013 FR-002: the check in the model reads the account count before inserting,
    # so two signups landing together can both find it empty. The index is what
    # actually holds — only one row may carry the flag — and the model rescues the
    # rejection for the loser. Partial, because the constraint is "at most one
    # true", not "every value distinct": false has to stay free to repeat.
    add_index :users, :admin, unique: true, where: "admin = 1"
  end
end
