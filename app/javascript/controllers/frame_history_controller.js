import { Controller } from "@hotwired/stimulus"

// 017 FR-018: Back and Forward must bring back the list that goes with the
// address, not merely the address.
//
// A filter change advances the history from inside the frame, which is what keeps
// the change local (FR-009) while still making the filtered view addressable. But
// Turbo's restoration visit for such an entry does not reliably re-render the
// frame — measured at two runs in five, with no amount of waiting helping — so the
// address could end up describing a list that was not on screen.
//
// This closes that gap without giving up either requirement. On a history
// movement, Turbo is given its chance first; if it did not replace the page — the
// frame this controller is attached to is still in the document — the frame is
// pointed at the address, and fetches the list that belongs to it.
export default class extends Controller {
  connect() {
    this.restore = this.restore.bind(this)
    window.addEventListener("popstate", this.restore)
  }

  disconnect() {
    window.removeEventListener("popstate", this.restore)
  }

  restore() {
    const frame = this.element

    requestAnimationFrame(() => {
      // Still connected means Turbo left the page alone and the frame is showing
      // the filters from before the history moved. Disconnected means Turbo
      // re-rendered and its copy is already correct — leave it be.
      if (frame.isConnected) frame.src = window.location.href
    })
  }
}
