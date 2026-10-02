require "test_helper"

# Documentation gate (constitution, Quality Gates). README.md is a landing page
# and the reference material lives under docs/, so a page that is moved or
# renamed leaves a broken link behind that nothing else notices.
#
# No browser needed: this reads the Markdown as text and runs in the unit suite.
# It checks relative links to files and, for links into a Markdown file, that the
# #anchor names a real heading. External links are not followed.
class DocumentationLinksTest < ActiveSupport::TestCase
  PAGES = %w[README.md CONTRIBUTING.md SECURITY.md CLAUDE.md].freeze
  # Markdown links, and the href="" of the HTML the README header is written in.
  LINK = /(?<!!)\[[^\]]*\]\(([^)\s]+)\)|href="([^"]+)"/

  test "the pages are found" do
    assert_operator documents.size, :>=, 6, "expected README, the project files and docs/*.md"
  end

  test "every relative link in the documentation points at a file that exists" do
    broken = links.reject { |doc, target, _| target.empty? || path_for(doc, target).exist? }

    assert_empty broken.map { |doc, target, _| "#{relative(doc)} -> #{target}" }
  end

  test "every anchor into a Markdown page names a heading that exists" do
    broken = links.select { |_, _, anchor| anchor.present? }.reject do |doc, target, anchor|
      file = target.empty? ? doc : path_for(doc, target)
      file.extname == ".md" ? anchors_in(file).include?(anchor) : true
    end

    assert_empty broken.map { |doc, target, anchor| "#{relative(doc)} -> #{target}##{anchor}" }
  end

  test "every spec-linked feature in docs/features.md has a spec directory" do
    missing = File.read(Rails.root.join("docs/features.md")).scan(%r{\(\.\./specs/([^/)]+)/}).flatten.uniq.reject do |dir|
      Rails.root.join("specs", dir).directory?
    end

    assert_empty missing
  end

  private
    def documents
      @documents ||= (PAGES.map { Rails.root.join(_1) } + Dir[Rails.root.join("docs/*.md")].map { Pathname(_1) }).select(&:exist?)
    end

    # [document, file target (may be empty for same-page), anchor (may be "")]
    def links
      @links ||= documents.flat_map do |doc|
        strip_code(doc.read).scan(LINK).map { _1.compact.first }.filter_map do |href|
          next if href.match?(%r{\A([a-z][a-z0-9+.-]*:|//)}i)
          target, anchor = href.split("#", 2)
          [ doc, target.to_s, anchor.to_s ]
        end
      end
    end

    def path_for(doc, target) = (doc.dirname + target).cleanpath

    def relative(doc) = doc.relative_path_from(Rails.root)

    # Fenced and inline code hold example syntax, not links.
    def strip_code(text) = text.gsub(/^```.*?^```/m, "").gsub(/`[^`\n]*`/, "")

    # GitHub's heading slug: lowercase, punctuation dropped, spaces to hyphens.
    # An emoji is dropped but the space after it stays, hence the leading hyphen
    # the old README's "#-email" anchors relied on.
    def anchors_in(file)
      strip_fences(file.read).scan(/^\#{1,6}\s+(.+?)\s*$/).flatten.map do |heading|
        heading.downcase.gsub(/[^\p{L}\p{N}\s_-]/, "").gsub(/\s/, "-")
      end
    end

    def strip_fences(text) = text.gsub(/^```.*?^```/m, "")
end
