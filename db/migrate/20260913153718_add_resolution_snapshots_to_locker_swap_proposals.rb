# 005 FR-009: what each side's locker looked like when the proposal was settled.
# Copied onto the proposal rather than read back from the users, because the two
# are free to change their details again the moment the lock lifts — and a
# history entry that rewrote itself afterwards would be describing an exchange
# that never happened.
class AddResolutionSnapshotsToLockerSwapProposals < ActiveRecord::Migration[8.1]
  def change
    add_column :locker_swap_proposals, :requester_floor_at_resolution, :string
    add_column :locker_swap_proposals, :requester_locker_number_at_resolution, :string
    add_column :locker_swap_proposals, :recipient_floor_at_resolution, :string
    add_column :locker_swap_proposals, :recipient_locker_number_at_resolution, :string
  end
end
