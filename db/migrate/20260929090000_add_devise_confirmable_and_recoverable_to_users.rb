class AddDeviseConfirmableAndRecoverableToUsers < ActiveRecord::Migration[8.1]
  # up/down rather than change, because of the backfill below.
  def up
    # 034: the columns Devise's :confirmable (activation, email reconfirmation)
    # and :recoverable (password reset) keep their state in. All nullable —
    # data-model.md.
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime

    # The lookup keys confirm_by_token and reset_password_by_token search by.
    add_index :users, :confirmation_token, unique: true
    add_index :users, :reset_password_token, unique: true

    # FR-010 (clarified): every account that exists at release is activated —
    # nobody who could sign in yesterday is locked out today. Stamped with the
    # release moment rather than created_at, which would claim an activation
    # that never happened (research.md R15).
    execute "UPDATE users SET confirmed_at = CURRENT_TIMESTAMP WHERE confirmed_at IS NULL"
  end

  def down
    remove_index :users, :reset_password_token
    remove_index :users, :confirmation_token

    remove_column :users, :reset_password_sent_at
    remove_column :users, :reset_password_token
    remove_column :users, :unconfirmed_email
    remove_column :users, :confirmation_sent_at
    remove_column :users, :confirmed_at
    remove_column :users, :confirmation_token
  end
end
