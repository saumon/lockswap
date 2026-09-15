import { Controller } from "@hotwired/stimulus"

// Dismissal for the signed-in menu's narrow treatment: Escape, and activating
// anything outside the panel.
//
// This controller is an ENHANCEMENT and nothing here is load-bearing. The menu
// is a <details>, so opening it, closing it, operating it from the keyboard and
// announcing its state all happen natively — if this file never loads, the
// toggle still opens and closes the panel and every destination stays reachable
// (FR-010b, FR-010b-ii). What is added on top is the dismissal people expect
// from a menu but that <details> does not give you.
//
// Note the asymmetry: this only ever REMOVES the open attribute, never adds it.
// Opening is the summary's job. Keeping it that way is what stops the menu from
// quietly acquiring a script dependency.
export default class extends Controller {
  connect() {
    this.onDocumentKeydown = this.onDocumentKeydown.bind(this)
    this.onDocumentPointerdown = this.onDocumentPointerdown.bind(this)

    // Listeners go on the document because the events being watched for happen
    // by definition outside this element.
    document.addEventListener("keydown", this.onDocumentKeydown)
    document.addEventListener("pointerdown", this.onDocumentPointerdown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onDocumentKeydown)
    document.removeEventListener("pointerdown", this.onDocumentPointerdown)
  }

  onDocumentKeydown(event) {
    if (event.key !== "Escape" || !this.element.open) return

    // Focus is returned to the toggle before the panel closes. Escape pressed
    // from inside the panel would otherwise drop focus onto the body, and the
    // next Tab would restart from the top of the document — the keyboard
    // equivalent of being thrown out of the menu rather than stepping back from
    // it (FR-015).
    this.summary?.focus()
    this.close()
  }

  onDocumentPointerdown(event) {
    if (!this.element.open) return
    if (this.element.contains(event.target)) return

    this.close()
  }

  // FR-010c: a panel left open would hang over whatever the click loaded. Turbo
  // replaces the body on navigation, so in the ordinary case this element is
  // torn down anyway — but a same-page visit can restore a cached snapshot with
  // the attribute still set, which is what this guards against.
  close() {
    this.element.removeAttribute("open")
  }

  get summary() {
    return this.element.querySelector("summary")
  }
}
