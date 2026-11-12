import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.originalOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
  }

  disconnect() {
    document.body.style.overflow = this.originalOverflow || ""
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }

    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    } else {
      this.element.remove()
    }
  }
}
