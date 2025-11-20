import { Controller } from "@hotwired/stimulus"

/**
 * Evaluator Configs Stimulus Controller
 * Manages evaluator selection, configuration forms, and syncs to a hidden JSON field
 */
export default class extends Controller {
  static targets = ["checkbox", "config", "threshold", "weight", "configJson", "hiddenField", "configFormContainer"]

  connect() {
    this.loadConfigForms()
    this.updateJson()
  }

  /**
   * Load dynamic configuration forms for all evaluators with config_schema
   */
  loadConfigForms() {
    this.configFormContainerTargets.forEach(container => {
      const evaluatorKey = container.dataset.evaluatorKey
      this.loadEvaluatorConfigForm(evaluatorKey, container)
    })
  }

  /**
   * Load configuration form for a specific evaluator
   */
  loadEvaluatorConfigForm(evaluatorKey, container) {
    const url = `/prompt_tracker/evaluator_configs/config_form?evaluator_key=${evaluatorKey}`

    fetch(url)
      .then(response => {
        if (!response.ok) {
          throw new Error('Configuration form not found')
        }
        return response.text()
      })
      .then(html => {
        container.innerHTML = html

        // Add event listeners to all form inputs to sync with hidden field
        container.querySelectorAll('input, select, textarea').forEach(input => {
          input.addEventListener('change', () => this.syncEvaluatorConfig(evaluatorKey))
          input.addEventListener('input', () => this.syncEvaluatorConfig(evaluatorKey))
        })

        // Load existing config values into the form
        this.loadExistingConfigValues(evaluatorKey, container)
      })
      .catch(error => {
        console.error('Error loading configuration form:', error)
        container.innerHTML = `
          <div class="alert alert-warning alert-sm">
            <small>No custom form available. Using default configuration.</small>
          </div>
        `
      })
  }

  /**
   * Load existing configuration values into the form
   */
  loadExistingConfigValues(evaluatorKey, container) {
    const hiddenField = this.configJsonTargets.find(
      field => field.dataset.evaluatorKey === evaluatorKey
    )

    if (!hiddenField || !hiddenField.value) return

    try {
      const config = JSON.parse(hiddenField.value)

      // Set values for all form inputs based on config
      Object.keys(config).forEach(key => {
        const input = container.querySelector(`[name="config[${key}]"]`)
        if (input) {
          if (input.type === 'checkbox') {
            input.checked = config[key]
          } else if (input.tagName === 'SELECT' && input.multiple) {
            // Handle multi-select
            const values = Array.isArray(config[key]) ? config[key] : [config[key]]
            Array.from(input.options).forEach(option => {
              option.selected = values.includes(option.value)
            })
          } else {
            input.value = typeof config[key] === 'object' ? JSON.stringify(config[key]) : config[key]
          }
        }
      })
    } catch (e) {
      console.error('Error loading existing config values:', e)
    }
  }

  /**
   * Sync evaluator configuration from form to hidden field
   */
  syncEvaluatorConfig(evaluatorKey) {
    const container = this.configFormContainerTargets.find(
      c => c.dataset.evaluatorKey === evaluatorKey
    )
    const hiddenField = this.configJsonTargets.find(
      field => field.dataset.evaluatorKey === evaluatorKey
    )

    if (!container || !hiddenField) return

    const config = {}

    // Collect all form values
    container.querySelectorAll('[name^="config["]').forEach(input => {
      const match = input.name.match(/config\[([^\]]+)\]/)
      if (!match) return

      const key = match[1]

      if (input.type === 'checkbox') {
        config[key] = input.checked
      } else if (input.tagName === 'SELECT' && input.multiple) {
        // Handle multi-select
        config[key] = Array.from(input.selectedOptions).map(opt => opt.value)
      } else if (input.type === 'number') {
        config[key] = parseFloat(input.value) || 0
      } else {
        config[key] = input.value
      }
    })

    hiddenField.value = JSON.stringify(config)
    this.updateJson()
  }

  /**
   * Toggle evaluator config visibility when checkbox changes
   */
  toggleConfig(event) {
    const checkbox = event.target
    const key = checkbox.dataset.evaluatorKey
    const configDiv = this.configTargets.find(
      target => target.id === `config_${key}`
    )

    if (configDiv) {
      if (checkbox.checked) {
        configDiv.classList.remove('collapse')
      } else {
        configDiv.classList.add('collapse')
      }
    }

    this.updateJson()
  }

  /**
   * Update the hidden JSON field with all selected evaluator configurations
   */
  updateJson() {
    const configs = []

    this.checkboxTargets.forEach(checkbox => {
      if (!checkbox.checked) return

      const key = checkbox.dataset.evaluatorKey
      const thresholdInput = this.thresholdTargets.find(
        t => t.dataset.evaluatorKey === key
      )
      const weightInput = this.weightTargets.find(
        w => w.dataset.evaluatorKey === key
      )
      const configHiddenField = this.configJsonTargets.find(
        field => field.dataset.evaluatorKey === key
      )

      let config = {}
      if (configHiddenField && configHiddenField.value) {
        try {
          config = JSON.parse(configHiddenField.value)
        } catch (e) {
          config = {}
        }
      }

      configs.push({
        evaluator_key: key,
        threshold: parseFloat(thresholdInput?.value || 80),
        weight: parseFloat(weightInput?.value || 0.5),
        config: config
      })
    })

    this.hiddenFieldTarget.value = JSON.stringify(configs)
  }
}
