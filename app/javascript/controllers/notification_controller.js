import { Controller } from "@hotwired/stimulus"

// Shows a flash message for a few seconds and then takes it away again. The
// element is removed rather than hidden, so a dismissed notification leaves
// nothing behind for the next assertion — or the next screen reader — to find.
export default class extends Controller {
  static values = { duration: Number }

  // 023/FR-004: dismiss() plays the toast-leave animation (application.css)
  // before removing the element instead of removing it outright. This is a
  // safety margin above --motion-entrance (240ms), not a duration of its own —
  // it only fires if "animationend" never does (prefers-reduced-motion drops
  // the animation entirely, so nothing else would ever remove the element).
  static LEAVE_FALLBACK_MS = 300

  connect() {
    this.remaining = this.durationValue

    // 023/FR-010: toast_layer_controller#enqueue marks an over-the-cap toast
    // as queued *before* it is attached to the DOM — so if this attribute is
    // present the moment we connect, it was set before we could possibly have
    // raced it. A queued toast waits for restart(), called from release().
    if (this.element.dataset.notificationQueued === "true") return

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

  // Called by toast_layer_controller#release when this toast is promoted out
  // of the queue — a full duration_ms countdown, not whatever was left over
  // from before it was queued (data-model.md's Toast Layer transition rule).
  restart() {
    this.remaining = this.durationValue
    this.start()
  }

  dismiss() {
    this.clear()
    this.leave()
  }

  // Plays the exit animation, then removes the element — from whichever
  // fires first, the animation itself or the fallback. Guarded so a second
  // call (e.g. the dismiss button clicked while the countdown is also
  // finishing) cannot start the animation twice.
  leave() {
    if (this.element.classList.contains("is-leaving")) return
    this.element.classList.add("is-leaving")

    const layer = this.element.closest(".toast-layer")

    const finish = () => {
      clearTimeout(fallback)
      this.element.removeEventListener("animationend", finish)
      this.element.remove()

      // 023/FR-010: tell the layer a visible slot just freed, so it can
      // promote the oldest queued toast, if any is waiting.
      if (layer) {
        this.application.getControllerForElementAndIdentifier(layer, "toast-layer")?.release()
      }
    }

    const fallback = setTimeout(finish, this.constructor.LEAVE_FALLBACK_MS)
    this.element.addEventListener("animationend", finish, { once: true })
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
