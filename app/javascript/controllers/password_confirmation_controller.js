import { Controller } from "@hotwired/stimulus"

// Tells someone the two passwords disagree while they can still do something
// about it, rather than making them submit the form to find out (014 FR-004).
//
// This is a hint, not the rule. The two fields are compared again on the server,
// which is what actually refuses the signup (FR-002, FR-009) — the form is
// novalidate precisely so that every refusal comes from one place. With this
// script missing every form still behaves correctly, just less talkative.
//
// 035 (research.md R7): on the account page's password form it also says when
// the new password is too short or too long, and — that form only, through the
// guard action — holds back a submission it can already tell will be refused.
// A refused submission comes back with every password field empty (nothing
// typed is ever sent back to the page), so catching these two here is what
// keeps the user's typing (clarification Q2). Everything 035 adds is optional:
// signup and reset declare no lengthHint target and no guard, and behave
// exactly as before. The texts shown are rendered by the server from the same
// messages it would refuse with, so the two cannot drift.
export default class extends Controller {
  static targets = ["password", "confirmation", "hint", "lengthHint"]
  static values = { minimum: Number, maximum: Number, tooShort: String, tooLong: String }

  connect() {
    this.touched = false
    this.lengthTouched = false
  }

  // Leaving the field is the first thing that can be called finishing: until
  // then the confirmation is a value halfway through being given, and every
  // password typed one character at a time starts out not matching.
  confirm() {
    this.touched = true
    this.render()
  }

  // 035: the same, for the new password's length.
  measure() {
    this.lengthTouched = true
    this.render()
  }

  // Once it has been said, it is kept current — editing either field updates
  // the answer straight away, with no second blur and no round trip (FR-004,
  // SC-004). Before then this stays quiet.
  recheck() {
    if (this.touched || this.lengthTouched) this.render()
  }

  // 035 FR-015: a submission that would only come back refused for length or
  // mismatch is not sent. Both answers are shown, and focus goes to the first
  // field to fix. Anything else — an empty field, a wrong current password —
  // is left to the server.
  guard(event) {
    const lengthWrong = this.#lengthWrong()
    const mismatched = this.#mismatched()
    if (!lengthWrong && !mismatched) return

    event.preventDefault()
    this.touched = true
    this.lengthTouched = true
    this.render()
    ;(lengthWrong ? this.passwordTarget : this.confirmationTarget).focus()
  }

  render() {
    if (this.touched) this.hintTarget.hidden = !this.#mismatched()
    if (this.hasLengthHintTarget && this.lengthTouched) {
      this.lengthHintTarget.hidden = !this.#lengthWrong()
      this.lengthHintTarget.textContent =
        this.passwordTarget.value.length > this.maximumValue ? this.tooLongValue : this.tooShortValue
    }
  }

  #mismatched() {
    return this.confirmationTarget.value !== this.passwordTarget.value
  }

  // An empty field is the server's "is required", not a length problem.
  #lengthWrong() {
    if (!this.hasLengthHintTarget) return false

    const length = this.passwordTarget.value.length
    return length > 0 && (length < this.minimumValue || length > this.maximumValue)
  }
}
