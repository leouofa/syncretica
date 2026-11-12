import { Controller } from "@hotwired/stimulus"

const THRESHOLD_MAP = {
  1: 0.16,
  2: 0.17,
  3: 0.18,
  4: 0.19,
  5: 0.20,
  6: 0.21,
  7: 0.22,
  8: 0.23,
  9: 0.24,
  10: 0.25,
  11: 0.24,
  12: 0.24,
  13: 0.24,
  14: 0.23,
  15: 0.22
}

export default class extends Controller {
  static targets = ["slider", "badge", "spinner", "coverageToggle"]
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
    const level = parseInt(event.target.value, 10)
    const isFullCoverage = (this.hasCoverageToggleTarget && this.coverageToggleTarget.checked) || level >= 15
    const threshold = THRESHOLD_MAP[level] || 0.22

    if (level >= 15 && this.hasCoverageToggleTarget && !this.coverageToggleTarget.checked) {
      this.coverageToggleTarget.checked = true
    }

    this.updateBadge(level, threshold, isFullCoverage)
    this.updateModalFields(level, isFullCoverage)

    // Debounce network requests while sliding
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.fetchClusters(level, isFullCoverage)
    }, 200)
  }

  onChange(event) {
    clearTimeout(this.timeout)
    const level = parseInt(event.target.value, 10)
    const isFullCoverage = (this.hasCoverageToggleTarget && this.coverageToggleTarget.checked) || level >= 15
    this.fetchClusters(level, isFullCoverage)
  }

  onToggleCoverage(event) {
    const isFullCoverage = event.target.checked
    const level = this.hasSliderTarget ? parseInt(this.sliderTarget.value, 10) : 5
    const threshold = THRESHOLD_MAP[level] || 0.22

    this.updateBadge(level, threshold, isFullCoverage)
    this.updateModalFields(level, isFullCoverage)
    this.fetchClusters(level, isFullCoverage)
  }

  updateBadge(level, threshold, isFullCoverage) {
    if (this.hasBadgeTarget) {
      if (isFullCoverage) {
        this.badgeTarget.textContent = `Level ${level} • Complete Coverage (0 Singletons)`
      } else {
        this.badgeTarget.textContent = `Level ${level} • Distance ≤ ${threshold}`
      }
    }
  }

  updateModalFields(level, isFullCoverage) {
    const modalLevel = document.getElementById("modal_snapshot_level")
    if (modalLevel) {
      modalLevel.value = level
    }

    const modalCoverage = document.getElementById("modal_snapshot_full_coverage")
    if (modalCoverage) {
      modalCoverage.value = isFullCoverage
    }
  }

  async fetchClusters(level, isFullCoverage) {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }

    const targetUrl = new URL(this.urlValue, window.location.origin)
    targetUrl.searchParams.set("tab", this.tabValue)
    targetUrl.searchParams.set("level", level)
    if (isFullCoverage) {
      targetUrl.searchParams.set("full_coverage", "true")
    }

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
