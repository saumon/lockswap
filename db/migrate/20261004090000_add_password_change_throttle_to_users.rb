class AddPasswordChangeThrottleToUsers < ActiveRecord::Migration[8.1]
  def change
    # 035 FR-008, research.md R5: consecutive wrong current passwords on the
    # account page's password form, and when that form was throttled. Separate
    # from Devise's :lockable failed_attempts/locked_at on purpose — this
    # throttle must not lock anyone out of signing in.
    add_column :users, :password_change_failed_attempts, :integer, default: 0, null: false
    add_column :users, :password_change_locked_at, :datetime
  end
end
