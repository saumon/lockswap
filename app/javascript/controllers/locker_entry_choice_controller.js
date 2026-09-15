import { Controller } from "@hotwired/stimulus"

// The first-entry choice: someone either fills in their locker or says they have
// none, and only the fields belonging to that answer are on screen (009 FR-001,
// FR-003).
//
// Without this the locker number field is simply left blank, which is the same
// data but a worse question: it asks everyone to answer something most of them
// have no answer to, and says nothing about what an empty field means.
export default class extends Controller {
  static targets = ["lockerNumberField", "declareNoLockerTrigger", "declareHasLockerTrigger"]

  // The field is cleared, not just hidden: a number typed before changing your
  // mind would otherwise be submitted against the declaration that there is no
  // locker — saved, and visible on the homepage a moment later (FR-004).
  declareNoLocker() {
    this.lockerNumberInput.value = ""
    this.lockerNumberShown = false
    this.declareHasLockerTriggerTarget.focus()
  }

  declareHasLocker() {
    this.lockerNumberShown = true
    this.declareNoLockerTriggerTarget.focus()
  }

  // Each trigger is replaced by its opposite, in the same place. Focus follows,
  // because the control that was just activated is the one being hidden: leaving
  // it there drops a keyboard user back to the top of the document.
  //
  // The floor is never touched, in either direction — it is required whichever
  // answer is given, so whatever has been typed there survives the switch
  // (FR-005).
  set lockerNumberShown(shown) {
    this.lockerNumberFieldTarget.hidden = !shown
    this.declareNoLockerTriggerTarget.hidden = !shown
    this.declareHasLockerTriggerTarget.hidden = shown
  }

  get lockerNumberInput() {
    return this.lockerNumberFieldTarget.querySelector("input")
  }
}
