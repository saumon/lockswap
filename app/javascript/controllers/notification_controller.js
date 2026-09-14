import { Controller } from "@hotwired/stimulus"

// Shows a flash message for a few seconds and then takes it away again. The
// element is removed rather than hidden, so a dismissed notification leaves
// nothing behind for the next assertion — or the next screen reader — to find.
export default class extends Controller {
  static values = { duration: Number }

  connect() {
    this.remaining = this.durationValue
    this.start()
  }

  disconnect() {
    this.clear()
  }

  // Three seconds is not long enough for every reader, so pointing at a message
  // or tabbing into it holds it open: one that vanishes mid-sentence is gone for
  // good, with no way to ask for it back.
  pause() {
    if (!this.timeout) return

    this.remaining -= Date.now() - this.startedAt
    this.clear()
  }

  resume() {
    if (this.timeout) return

    this.start()
  }

  dismiss() {
    this.clear()
    this.element.remove()
  }

  start() {
    this.startedAt = Date.now()
    this.timeout = setTimeout(() => this.dismiss(), this.remaining)
  }

  clear() {
    clearTimeout(this.timeout)
    this.timeout = null
  }
}
