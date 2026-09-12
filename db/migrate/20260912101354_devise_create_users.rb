# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Database authenticatable
      # NOCASE collation makes the unique index below case-insensitive at the
      # database level, backing up Devise's own downcasing of case_insensitive_keys.
      t.string :email,              null: false, default: "", collation: "NOCASE"
      t.string :encrypted_password, null: false, default: ""

      ## Rememberable — drives the 30-day persistent session (FR-007)
      t.datetime :remember_created_at

      ## Lockable — 5 consecutive failures lock the account for 15 minutes (FR-011)
      t.integer  :failed_attempts, default: 0, null: false
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
  end
end
