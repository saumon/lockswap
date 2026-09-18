require "test_helper"

# 016: the rules a configured domain has to satisfy before it is allowed to gate
# anybody's registration.
#
# Deliberately no fixture file for this table (research.md R5). `fixtures :all`
# in test_helper loads every YAML file for every test in the suite, so a fixture
# here would restrict registration site-wide — including in the seventy-odd tests
# elsewhere that sign accounts up at @example.com without knowing this feature
# exists. Each test that needs a configured domain says so itself.
class AllowedEmailDomainTest < ActiveSupport::TestCase
  test "a domain is required" do
    assert_not AllowedEmailDomain.new(domain: "").valid?
    assert_not AllowedEmailDomain.new(domain: nil).valid?
    assert_not AllowedEmailDomain.new(domain: "   ").valid?
  end

  test "an ordinary domain is accepted" do
    [ "company.com", "example.co.uk", "sub.example.com", "my-company.org", "a1.io" ].each do |domain|
      assert_predicate AllowedEmailDomain.new(domain: domain), :valid?, "#{domain} should be accepted"
    end
  end

  # FR-008, Edge Cases: the entries an administrator is most likely to type by
  # mistake. An email address rather than a domain is the one worth naming — it
  # is the plausible slip, not a typo.
  test "a value that is not a domain is refused" do
    [ "not a domain", "user@company.com", "company", "company..com", "-company.com",
      "company.com/path", "http://company.com", "café.com" ].each do |value|
      assert_not_predicate AllowedEmailDomain.new(domain: value), :valid?, "#{value} should be refused"
    end
  end

  test "the refusal says what a domain looks like" do
    domain = AllowedEmailDomain.new(domain: "not a domain")
    domain.validate

    assert_includes domain.errors.full_messages.join, "company.com"
  end

  # Edge Cases: stray whitespace and casing are normalized rather than refused —
  # an administrator who pastes " Company.COM " meant company.com.
  test "casing and surrounding whitespace are normalized away" do
    domain = AllowedEmailDomain.create!(domain: "  Company.COM  ")

    assert_equal "company.com", domain.reload.domain
  end

  # Edge Cases: no functional duplicates. The normalization above is what makes
  # this a plain uniqueness check rather than a case-insensitive one — by the
  # time the validator runs, both spellings are the same string.
  test "a domain already on the list is refused, whatever its casing" do
    AllowedEmailDomain.create!(domain: "company.com")

    assert_not_predicate AllowedEmailDomain.new(domain: "COMPANY.com"), :valid?
    assert_not_predicate AllowedEmailDomain.new(domain: " company.com "), :valid?
  end

  # The unique index, not the validator: two requests can both pass validation
  # before either commits. This asserts the database is the thing that actually
  # holds, so the guarantee survives concurrency.
  test "the database refuses a duplicate the validator did not see" do
    AllowedEmailDomain.create!(domain: "company.com")

    assert_raises ActiveRecord::RecordNotUnique do
      AllowedEmailDomain.insert!({ domain: "company.com", created_at: Time.current, updated_at: Time.current })
    end
  end
end
