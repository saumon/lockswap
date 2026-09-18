import { Controller } from "@hotwired/stimulus"

// Tells someone the two passwords disagree while they can still do something
// about it, rather than making them submit the form to find out (014 FR-004).
//
// This is a hint, not the rule. The two fields are compared again on the server,
// which is what actually refuses the signup (FR-002, FR-009) — the form is
// novalidate precisely so that every refusal comes from one place. Nothing here
// blocks a submission, and with this script missing the signup still behaves
// correctly, just less talkative.
export default class extends Controller {
  static targets = ["password", "confirmation", "hint"]

  connect() {
    this.touched = false
  }

  // Leaving the field is the first thing that can be called finishing: until
  // then the confirmation is a value halfway through being given, and every
  // password typed one character at a time starts out not matching.
  confirm() {
    this.touched = true
    this.render()
  }

  // Once it has been said, it is kept current — editing either field updates
  // the answer straight away, with no second blur and no round trip (FR-004,
  // SC-004). Before then this stays quiet.
  recheck() {
    if (this.touched) this.render()
  }

  render() {
    this.hintTarget.hidden = this.confirmationTarget.value === this.passwordTarget.value
  }
}
