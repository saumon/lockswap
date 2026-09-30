# 034: reading the account emails back in tests.
#
# Every Devise email is delivered with deliver_later (User#send_devise_notification),
# so in tests it sits in the Active Job test adapter until something performs it.
# These helpers perform it and pull the link out, so a system test can follow an
# activation or reset link exactly as a person would.
module MailHelpers
  extend ActiveSupport::Concern

  included do
    include ActiveJob::TestHelper
    include ActionMailer::TestHelper
  end

  # Delivers whatever is waiting, then returns the path of the first link in the
  # newest email whose URL matches pattern — ready to hand to `visit`.
  def link_from_last_email(pattern)
    deliver_enqueued_emails
    mail = ActionMailer::Base.deliveries.last
    assert mail, "no email was delivered"

    url = mail.text_part.decoded.scan(%r{https?://\S+}).find { |candidate| candidate.match?(pattern) }
    assert url, "no link matching #{pattern.inspect} in the last email:\n#{mail.text_part.decoded}"

    URI.parse(url).request_uri
  end

  # Every delivered email addressed to address.
  def emails_to(address)
    deliver_enqueued_emails
    ActionMailer::Base.deliveries.select { |mail| mail.to.include?(address) }
  end
end
