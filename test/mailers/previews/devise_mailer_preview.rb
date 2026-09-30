# 034: the four account emails, at /rails/mailers in development — so the
# design is reviewed by looking at it (CLAUDE.md, "How to check the work").
# Each renders in the site's current language; switch it on the Danger Zone to
# see the other.
class DeviseMailerPreview < ActionMailer::Preview
  def activation
    UserMailer.confirmation_instructions(user, "preview-token")
  end

  def reconfirmation
    changing = user
    changing.unconfirmed_email = "new.address@example.com"
    UserMailer.confirmation_instructions(changing, "preview-token", to: changing.unconfirmed_email)
  end

  def reset_password
    UserMailer.reset_password_instructions(user, "preview-token")
  end

  def password_change
    UserMailer.password_change(user)
  end

  private

    # Unsaved: a preview must never write to the database it is looking at.
    def user
      User.new(email: "preview@example.com")
    end
end
