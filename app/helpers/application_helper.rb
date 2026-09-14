module ApplicationHelper
  # 008 FR-025: maps a proposal's status onto its badge tint. The tint is
  # decoration; the status word next to it is what carries the meaning, so a
  # reader who cannot distinguish the colours loses nothing.
  def history_status_badge_class(proposal)
    case proposal.status
    when "completed" then "badge-success"
    when "accepted"  then "badge-success"
    when "declined"  then "badge-error"
    when "proposed"  then "badge-info"
    else                  "badge-neutral"
    end
  end
end
