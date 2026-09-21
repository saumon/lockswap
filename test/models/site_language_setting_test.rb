require "test_helper"

# 025: the singleton guarantee and the two-value constraint that make
# SiteLanguageSetting.current safe for every controller/view to call on every
# request.
#
# Deliberately no fixture file for this table (research.md R9, mirroring 016
# R5's reasoning for allowed_email_domains): `fixtures :all` in test_helper
# loads every YAML file for every test in the suite, so a fixture here would
# fix the language every other test in the application renders under, and
# would specifically defeat the "empty table defaults to English" case below.
class SiteLanguageSettingTest < ActiveSupport::TestCase
  test "language must be en or fr" do
    assert_not SiteLanguageSetting.new(language: "de").valid?
    assert_not SiteLanguageSetting.new(language: "").valid?
    assert_not SiteLanguageSetting.new(language: nil).valid?
  end

  test "en and fr are both accepted" do
    assert_predicate SiteLanguageSetting.new(language: "en"), :valid?
    assert_predicate SiteLanguageSetting.new(language: "fr"), :valid?
  end

  test "a second row is refused" do
    SiteLanguageSetting.create!(language: "en")

    second = SiteLanguageSetting.new(language: "fr")

    assert_not second.valid?
    assert_includes second.errors[:base], "only one site language setting may exist"
  end

  test "an existing row may still be updated" do
    setting = SiteLanguageSetting.create!(language: "en")

    setting.language = "fr"

    assert_predicate setting, :valid?
  end

  test ".current creates the default-language row on a first call against an empty table" do
    assert_equal 0, SiteLanguageSetting.count

    current = SiteLanguageSetting.current

    assert_equal SiteLanguageSetting::DEFAULT_LANGUAGE, current.language
    assert_equal "en", current.language
    assert_equal 1, SiteLanguageSetting.count
  end

  test ".current returns the existing row rather than creating a second one" do
    first = SiteLanguageSetting.current
    first.update!(language: "fr")

    second_call = SiteLanguageSetting.current

    assert_equal first.id, second_call.id
    assert_equal "fr", second_call.language
    assert_equal 1, SiteLanguageSetting.count
  end
end
