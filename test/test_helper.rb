ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/mail_helpers"

module ActiveSupport
  class TestCase
    # Plaintext of the password hashed into test/fixtures/users.yml.
    VALID_PASSWORD = "password123".freeze

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # 034: every test can read back the account emails it caused.
    include MailHelpers
  end
end
