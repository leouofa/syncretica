import { Controller } from "@hotwired/stimulus"

const THRESHOLD_MAP = {
  1: 0.16,
  2: 0.17,
  3: 0.18,
  4: 0.20,
  5: 0.22,
  6: 0.24,
  7: 0.25,
  8: 0.26,
  9: 0.27,
  10: 0.28
}

export default class extends Controller {
  static targets = ["slider", "badge", "spinner"]
  static values = {
    tab: String,
    url: String
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  onSlide(event) {
    const level = event.target.value
    const threshold = THRESHOLD_MAP[level] || 0.22

    if (this.hasBadgeTarget) {
      this.badgeTarget.textContent = `Level ${level} • Cosine Distance ≤ ${threshold}`
    }

    const modalLevel = document.getElementById("modal_snapshot_level")
    if (modalLevel) {
      modalLevel.value = level
    }

    // Debounce network requests while sliding
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.fetchClusters(level)
    }, 200)
  }

  onChange(event) {
    clearTimeout(this.timeout)
    this.fetchClusters(event.target.value)
  }

  async fetchClusters(level) {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }

    const targetUrl = new URL(this.urlValue, window.location.origin)
    targetUrl.searchParams.set("tab", this.tabValue)
    targetUrl.searchParams.set("level", level)

    try {
      const response = await fetch(targetUrl.toString(), {
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        }
      })

      if (response.ok) {
        const streamText = await response.text()
        if (window.Turbo && typeof window.Turbo.renderStreamMessage === "function") {
          window.Turbo.renderStreamMessage(streamText)
        } else {
          // Fallback if renderStreamMessage is not directly exposed
          const frame = document.getElementById("clusters_content_frame")
          if (frame) {
            frame.src = targetUrl.toString()
          }
        }
        window.history.replaceState({}, "", targetUrl.toString())
      }
    } catch (error) {
      console.error("Failed to fetch clusters:", error)
    } finally {
      if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.add("hidden")
      }
    }
  }
}
