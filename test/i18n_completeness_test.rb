require "test_helper"
require "yaml"

# 025 research.md R9 (added during /speckit-analyze remediation, finding C1):
# `config.i18n.raise_on_missing_translations` only catches a key missing from
# every locale in the fallback chain — with `config.i18n.fallbacks = true`, a
# key present in en.yml but never translated to fr.yml resolves silently under
# any locale and raises nothing. This test is what actually proves SC-003 for
# the two locale-file pairs this application authors, independent of which
# views any system test happens to render.
#
# Reads the YAML files directly rather than I18n.backend's merged runtime
# translations, so this only ever asserts on keys this application is
# responsible for — not on devise-i18n's or rails-i18n's own upstream files,
# whose completeness is those gems' concern, not ours.
class I18nCompletenessTest < ActiveSupport::TestCase
  # T010/research.md R8: these keys are deliberately left absent from fr.yml's
  # own %w[en fr]-keyed structure — they live there as English values *under
  # the fr: root* on purpose (FR-012), not as translations of an en.yml key of
  # the same name, so the subset check below would otherwise flag them.
  PINNED_ENGLISH_ONLY_KEYS = %w[
    date.formats date.day_names date.abbr_day_names date.month_names date.abbr_month_names
    time.formats time.am time.pm
    number.format
  ].freeze

  def flatten_keys(hash, prefix = nil)
    hash.each_with_object([]) do |(key, value), keys|
      path = prefix ? "#{prefix}.#{key}" : key.to_s
      if value.is_a?(Hash)
        keys.concat(flatten_keys(value, path))
      else
        keys << path
      end
    end
  end

  def load_locale_keys(path, root)
    yaml = YAML.load_file(Rails.root.join(path))
    flatten_keys(yaml.fetch(root))
  end

  test "every key in en.yml has a French counterpart in fr.yml" do
    en_keys = load_locale_keys("config/locales/en.yml", "en") - PINNED_ENGLISH_ONLY_KEYS
    fr_keys = load_locale_keys("config/locales/fr.yml", "fr")

    missing = en_keys - fr_keys

    assert_empty missing, "keys present in en.yml but missing from fr.yml: #{missing.join(', ')}"
  end

  test "every key in devise.en.yml has a French counterpart, ours or devise-i18n's" do
    # Most of devise.en.yml restates Devise's own stock English text verbatim
    # (a handful of keys are genuinely LockSwap-specific — 007's uniform
    # failure messages, 014's password_confirmation wording — and those alone
    # are what this app's own devise.fr.yml provides). A restated-but-unchanged
    # key does not need our own French translation: the devise-i18n gem this
    # app depends on (research.md R5) already speaks French for it, so a key
    # is satisfied by either file.
    en_keys = load_locale_keys("config/locales/devise.en.yml", "en")
    our_fr_keys = load_locale_keys("config/locales/devise.fr.yml", "fr")
    devise_i18n_fr_path = Gem.loaded_specs.fetch("devise-i18n").gem_dir + "/rails/locales/fr.yml"
    gem_fr_keys = load_locale_keys(devise_i18n_fr_path, "fr")

    missing = en_keys - our_fr_keys - gem_fr_keys

    assert_empty missing, "keys present in devise.en.yml but covered by neither devise.fr.yml nor devise-i18n's own French file: #{missing.join(', ')}"
  end
end
