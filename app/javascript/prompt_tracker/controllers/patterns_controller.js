import { Controller } from "@hotwired/stimulus"

/**
 * Patterns Stimulus Controller
 * Manages adding/removing pattern inputs and syncs them to a hidden JSON field
 */
export default class extends Controller {
  static targets = ["list", "input", "hiddenField", "noMessage"]

  connect() {
    this.updateJson()
  }

  /**
   * Add a new pattern input
   */
  addPattern() {
    // Remove "no patterns" message if it exists
    if (this.hasNoMessageTarget) {
      this.noMessageTarget.remove()
    }

    const patternItem = document.createElement('div')
    patternItem.className = 'input-group mb-2 pattern-item'
    patternItem.innerHTML = `
      <span class="input-group-text"><i class="bi bi-regex"></i></span>
      <input type="text" 
             class="form-control" 
             data-patterns-target="input"
             data-action="input->patterns#updateJson"
             placeholder="e.g., /Hello/ or /\\d{3}-\\d{4}/">
      <button type="button" 
              class="btn btn-outline-danger"
              data-action="click->patterns#removePattern">
        <i class="bi bi-trash"></i>
      </button>
    `

    this.listTarget.appendChild(patternItem)
    this.updateJson()
  }

  /**
   * Remove a pattern input
   */
  removePattern(event) {
    const patternItem = event.target.closest('.pattern-item')
    patternItem.remove()
    this.updateJson()

    // Show "no patterns" message if list is empty
    if (this.listTarget.querySelectorAll('.pattern-item').length === 0) {
      this.listTarget.innerHTML = `
        <div class="text-muted text-center py-3" data-patterns-target="noMessage">
          <i class="bi bi-info-circle"></i> No patterns defined. Click "Add Pattern" to add one.
        </div>
      `
    }
  }

  /**
   * Update the hidden JSON field with current patterns
   */
  updateJson() {
    const patterns = []
    
    this.inputTargets.forEach(input => {
      if (input.value.trim()) {
        patterns.push(input.value.trim())
      }
    })

    this.hiddenFieldTarget.value = JSON.stringify(patterns)
  }
}

