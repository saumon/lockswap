import { Controller } from "@hotwired/stimulus"

// Mediates the visible-count cap and reveal queue (FR-010, data-model.md's
// "Toast Layer"): at most CAP toasts count down at once, and any beyond that
// wait — hidden, not counting down — until a visible one clears.
//
// The cap only applies to toasts added through enqueue(). A toast already
// present in the server-rendered page (at most two, well under CAP) is never
// routed through it and simply starts immediately, as it always has. Nothing
// in this app appends a toast after page load yet; enqueue() is the seam a
// future live mechanism (a Turbo Stream action, say) would call through
// instead of appending directly, so it inherits the same cap for free.
export default class extends Controller {
  static targets = [ "toast" ]

  CAP = 3

  connect() {
    this.queue = []
  }

  // The queued/not-queued decision happens here, synchronously, before the
  // element is ever attached to the DOM — so there is no race between this
  // and the new toast's own notification controller connecting: the element
  // does not exist for Stimulus to discover until this method decides.
  enqueue(element) {
    if (this.visibleCount() >= this.CAP) {
      element.hidden = true
      element.dataset.notificationQueued = "true"
      this.queue.push(element)
    }

    this.element.append(element)
  }

  // Called by a toast's own notification_controller once it has finished
  // leaving (application.css's toast-leave, or its fallback) and removed
  // itself — promotes the oldest queued toast, FIFO, if one is waiting.
  release() {
    const next = this.queue.shift()
    if (!next) return

    // Clearing [hidden] alone replays .toast's entrance animation (T006):
    // browsers reset a CSS animation when its element stops rendering
    // (display: none) and restart it fresh once rendering resumes — no class
    // toggle or reflow trick needed for a toast revealed from the queue to
    // settle in exactly like one shown immediately.
    next.hidden = false
    delete next.dataset.notificationQueued

    this.application
      .getControllerForElementAndIdentifier(next, "notification")
      ?.restart()
  }

  visibleCount() {
    return this.toastTargets.filter((toast) => !toast.hidden).length
  }
}
