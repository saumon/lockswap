# 034 research.md R13: the design tokens, for email.
#
# CLAUDE.md forbids a colour literal in a template, and email clients ignore
# CSS custom properties — so the mail templates cannot use the stylesheet's
# tokens directly, and must not spell out hex values either. They ask for a
# colour by its token's name here instead. Each value is copied from
# app/assets/tailwind/application.css; if a token changes there, change it here.
module MailerHelper
  MAIL_COLORS = {
    ink: "#0A1F38",         # --color-ink          16.11:1 on white
    ink_muted: "#50607A",   # --color-ink-muted     6.36:1 on white
    link: "#0A5AC2",        # --color-link          the button fill: white text on it is 6.45:1
    canvas: "#F4F7FA",      # --color-canvas
    surface: "#FFFFFF",     # --color-surface
    border: "#DCE4EC",      # --color-border       the card's border (decorative separation only)
    brand_green: "#0AB486", # --color-brand-green   wordmark only (WCAG SC 1.4.3 brand exemption)
    rail_you: "#0A77F1"     # --color-rail-you      the card's hinge: this email is about the reader's own account
  }.freeze

  # Webfonts are not loaded in mail; these stacks fall back the way the site's
  # two families would. Written for prose, measured for links and dates.
  MAIL_FONT_WRITTEN = "Nunito, system-ui, -apple-system, 'Segoe UI', sans-serif".freeze
  MAIL_FONT_MEASURED = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace".freeze

  def mail_color(name) = MAIL_COLORS.fetch(name)
end
