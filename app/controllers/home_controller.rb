# The site's homepage — the landing page every successful login arrives at (FR-005).
class HomeController < ApplicationController
  # FR-008: homepage content is never rendered to a visitor who is not logged in;
  # Devise redirects them to the login page instead.
  before_action :authenticate_user!

  def index
  end
end
