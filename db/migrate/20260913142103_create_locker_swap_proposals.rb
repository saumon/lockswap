class CreateLockerSwapProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :locker_swap_proposals do |t|
      # Two references to the same table, so each one names its own foreign key
      # and index rather than relying on the column name matching the table.
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }

      # pending(0) accepted(1) declined(2) withdrawn(3) completed(4). An integer
      # enum rather than a set of booleans: the states are mutually exclusive,
      # and separate flags would allow combinations like declined+completed.
      t.integer :status, null: false, default: 0

      # Only ever set alongside a decline — either the recipient's own words
      # (FR-008) or the system's, when acceptance elsewhere auto-declines this
      # one (FR-011).
      t.text :decline_comment

      t.datetime :decided_at
      t.datetime :completed_at
      # Set once the requester's homepage has shown them this decline, so the
      # notification stops reappearing on every later visit (FR-007, FR-009).
      t.datetime :requester_acknowledged_at

      t.timestamps
    end

    # The three rules that have to hold under concurrent submissions live here,
    # not only in the model: two requests can both pass an application-level
    # lookup before either commits (the same reasoning as 002's locker_number
    # and 003's user_id indexes).

    # At most one pending proposal per requester->recipient pair (FR-018).
    add_index :locker_swap_proposals, [ :requester_id, :recipient_id ],
              unique: true, where: "status = 0",
              name: "index_swap_proposals_pending_pair"

    # A user is the requester of at most one exchange in progress, and the
    # recipient of at most one (FR-003, FR-004). SQL has no cross-column
    # uniqueness, so these two cover the single-role races and
    # LockerSwapProposal#accept! re-checks both roles inside its transaction.
    add_index :locker_swap_proposals, :requester_id,
              unique: true, where: "status = 1",
              name: "index_swap_proposals_accepted_requester"
    add_index :locker_swap_proposals, :recipient_id,
              unique: true, where: "status = 1",
              name: "index_swap_proposals_accepted_recipient"
  end
end
