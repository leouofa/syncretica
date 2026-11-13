import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["promptInput"]

  selectPreset(event) {
    event.preventDefault()
    const button = event.currentTarget
    const promptText = button.dataset.promptPreset
    if (this.hasPromptInputTarget && promptText) {
      this.promptInputTarget.value = promptText
      this.promptInputTarget.focus()
    }
  }

  clear() {
    setTimeout(() => {
      if (this.hasPromptInputTarget) {
        this.promptInputTarget.value = ""
      }
    }, 0)
  }
}
