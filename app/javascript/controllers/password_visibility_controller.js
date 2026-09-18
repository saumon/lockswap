import { Controller } from "@hotwired/stimulus"

// Lets one password field be read back in plain text (014 FR-005).
//
// One instance per field, which is what makes the two independent: there is no
// shared state for them to disagree about, so FR-006 holds by construction
// rather than by remembering to scope something.
//
// The button's name changes with the state — "Show password" becomes "Hide
// password" — and is the only place the state is spelled out. It deliberately
// carries no aria-pressed as well: a control announced as "Hide password,
// pressed" is telling you two things at once and leaving you to work out which
// of them describes now and which describes what happens if you press it
// (FR-008). Which icon is drawn follows from the field's own type, in CSS, so
// nothing here has to keep a second copy of the answer.
export default class extends Controller {
  static targets = ["input", "button"]
  static values = { subject: String }

  toggle() {
    const revealing = this.inputTarget.type === "password"

    this.inputTarget.type = revealing ? "text" : "password"
    this.buttonTarget.setAttribute(
      "aria-label",
      `${revealing ? "Hide" : "Show"} ${this.subjectValue}`
    )
  }
}
