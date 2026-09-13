# The site's homepage — the landing page every successful login arrives at (FR-005).
class HomeController < ApplicationController
  include LoadsHomepageProposals

  # FR-008: homepage content is never rendered to a visitor who is not logged in;
  # Devise redirects them to the login page instead.
  before_action :authenticate_user!
  # 004 FR-009: the homepage is where proposals are noticed and acted on.
  before_action :load_homepage_proposals

  def index
  end
end
