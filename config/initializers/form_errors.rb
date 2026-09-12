# Rails wraps a field that failed validation in <div class="field_with_errors">,
# which says nothing to a screen reader and injects an extra block element into
# the form layout. Mark the field itself instead: aria-invalid for assistive
# technology, a red border for everyone else.
Rails.application.config.to_prepare do
  ActionView::Base.field_error_proc = proc do |html_tag, _instance|
    fragment = Nokogiri::HTML.fragment(html_tag)

    if (field = fragment.at_css("input, textarea, select"))
      field["aria-invalid"] = "true"
      # Swap the neutral border rather than appending, so the two utilities do
      # not compete for precedence in the generated stylesheet.
      classes = field["class"].to_s
      field["class"] = classes.include?("border-slate-300") ?
        classes.sub("border-slate-300", "border-rose-400") :
        "#{classes} border-rose-400".strip
      fragment.to_s.html_safe
    else
      html_tag
    end
  end
end
