import { Controller } from "@hotwired/stimulus"

// 020 research.md R2: the debounced half of the two text filters' "no Apply
// control, effect follows the input" behaviour. A link filter gets this for
// free — a click is one deliberate action — but a text field's natural
// analogue of "committing" is every keystroke, and firing a request per
// character would be the wrong cost for the same requirement. Debouncing is
// the minimum change that keeps the requirement true without that cost.
//
// Generic over whichever form it is attached to, the same way
// frame_history_controller.js is generic over whichever frame it is attached
// to: nothing here names "current locker" or "email".
const DEBOUNCE_MS = 400

export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  submit() {
    if (this.timeout) clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, DEBOUNCE_MS)
  }
}
