# Feature 1: Web UI Playground for Prompt Drafting/Templating

## 📋 Overview

A web-based playground interface that allows users to:
- Draft and edit prompt templates with Liquid syntax support
- Test templates with sample variables in real-time
- Preview rendered output before saving
- Create new prompt versions from the playground
- Compare different template variations side-by-side

## 🎯 Goals

1. **Enable rapid iteration** - Test prompt changes without deploying YAML files
2. **Support Liquid templating** - Upgrade from simple `{{variable}}` to full Liquid syntax
3. **Provide instant feedback** - See rendered output as you type
4. **Maintain version control** - Save playground experiments as draft versions
5. **Reduce friction** - Make prompt engineering accessible to non-developers

## 🏗️ Architecture

### Components

#### 1. **Liquid Template Engine Integration**
- **Gem**: `liquid` (already battle-tested by Shopify)
- **Location**: `app/services/prompt_tracker/template_renderer.rb`
- **Responsibilities**:
  - Render templates with Liquid syntax
  - Support filters (e.g., `{{ name | upcase }}`)
  - Support control flow (e.g., `{% if condition %}...{% endif %}`)
  - Support loops (e.g., `{% for item in items %}...{% endfor %}`)
  - Maintain backward compatibility with `{{variable}}` syntax

#### 2. **Playground Controller**
- **Location**: `app/controllers/prompt_tracker/playground_controller.rb`
- **Routes**:
  - `GET /prompts/:prompt_id/playground` - Show playground interface
  - `POST /prompts/:prompt_id/playground/preview` - AJAX endpoint for live preview
  - `POST /prompts/:prompt_id/playground/save` - Save as draft version
  - `GET /playground/new` - Create new prompt from scratch

#### 3. **Playground View**
- **Location**: `app/views/prompt_tracker/playground/show.html.erb`
- **Features**:
  - Split-pane layout (template editor | preview)
  - Syntax highlighting for Liquid templates
  - Variable input form (dynamic based on schema)
  - Live preview with debouncing
  - Template validation feedback
  - Save as draft button

#### 4. **JavaScript Components**
- **Location**: `app/assets/javascripts/prompt_tracker/playground.js`
- **Features**:
  - CodeMirror or Monaco editor for syntax highlighting
  - AJAX calls for live preview
  - Debounced input handling
  - Variable form generation
  - Error display

## 📊 Database Changes

### Option A: No Schema Changes (Recommended)
- Use existing `prompt_versions` table
- Save playground experiments as `status: "draft"`, `source: "playground"`
- Store Liquid templates in existing `template` column

### Option B: Add Playground Sessions (Future Enhancement)
```ruby
# Migration: create_prompt_tracker_playground_sessions.rb
create_table :prompt_tracker_playground_sessions do |t|
  t.references :prompt, foreign_key: { to_table: :prompt_tracker_prompts }
  t.references :user, type: :string, null: true
  t.text :template, null: false
  t.jsonb :variables_schema, default: []
  t.jsonb :sample_variables, default: {}
  t.text :rendered_output
  t.timestamps
end
```

## 🔧 Implementation Plan

### Phase 1: Liquid Template Engine (Week 1)

**Tasks:**
1. Add `liquid` gem to Gemfile
2. Create `TemplateRenderer` service
3. Update `PromptVersion#render` to support both syntaxes
4. Add template syntax validation
5. Write comprehensive tests

**Files to Create:**
- `app/services/prompt_tracker/template_renderer.rb`
- `spec/services/prompt_tracker/template_renderer_spec.rb`

**Files to Modify:**
- `Gemfile` - Add `gem 'liquid', '~> 5.5'`
- `app/models/prompt_tracker/prompt_version.rb` - Delegate to TemplateRenderer

**Example Implementation:**
```ruby
# app/services/prompt_tracker/template_renderer.rb
module PromptTracker
  class TemplateRenderer
    def self.render(template, variables = {})
      new(template, variables).render
    end

    def initialize(template, variables = {})
      @template = template
      @variables = variables.with_indifferent_access
    end

    def render
      # Try Liquid first
      liquid_template = Liquid::Template.parse(@template)
      liquid_template.render(@variables.stringify_keys)
    rescue Liquid::SyntaxError => e
      # Fallback to simple {{variable}} substitution
      rendered = @template.dup
      @variables.each do |key, value|
        rendered.gsub!("{{#{key}}}", value.to_s)
      end
      rendered
    end
  end
end
```

### Phase 2: Playground Controller & Routes (Week 1-2)

**Tasks:**
1. Create PlaygroundController
2. Add routes
3. Implement preview endpoint
4. Implement save endpoint
5. Add authorization/authentication

**Files to Create:**
- `app/controllers/prompt_tracker/playground_controller.rb`
- `spec/controllers/prompt_tracker/playground_controller_spec.rb`

**Files to Modify:**
- `config/routes.rb`

**Routes:**
```ruby
# config/routes.rb
resources :prompts do
  member do
    get :playground
    post 'playground/preview', to: 'playground#preview'
    post 'playground/save', to: 'playground#save'
  end
end

# Standalone playground for new prompts
resource :playground, only: [:new, :create], controller: 'playground'
```

**Controller Example:**
```ruby
# app/controllers/prompt_tracker/playground_controller.rb
module PromptTracker
  class PlaygroundController < ApplicationController
    before_action :set_prompt, only: [:show, :preview, :save]

    # GET /prompts/:id/playground
    def show
      @version = @prompt.active_version || @prompt.latest_version
      @sample_variables = extract_sample_variables(@version)
    end

    # POST /prompts/:id/playground/preview
    def preview
      template = params[:template]
      variables = params[:variables] || {}

      begin
        rendered = TemplateRenderer.render(template, variables)
        render json: {
          success: true,
          rendered: rendered,
          variables_detected: detect_variables(template)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end
    end

    # POST /prompts/:id/playground/save
    def save
      version = @prompt.prompt_versions.create!(
        template: params[:template],
        variables_schema: params[:variables_schema],
        model_config: params[:model_config] || {},
        notes: params[:notes],
        status: 'draft',
        source: 'playground'
      )

      redirect_to prompt_prompt_version_path(@prompt, version),
                  notice: 'Draft version created successfully!'
    rescue => e
      redirect_to playground_prompt_path(@prompt),
                  alert: "Error: #{e.message}"
    end

    private

    def set_prompt
      @prompt = Prompt.find(params[:id] || params[:prompt_id])
    end

    def detect_variables(template)
      # Extract both {{var}} and {{ var }} patterns
      simple_vars = template.scan(/\{\{\s*(\w+)\s*\}\}/).flatten
      # Extract Liquid variables
      liquid_vars = template.scan(/\{\{\s*(\w+)(?:\s*\|[^}]*)?\s*\}\}/).flatten
      (simple_vars + liquid_vars).uniq
    end

    def extract_sample_variables(version)
      return {} unless version&.variables_schema

      version.variables_schema.each_with_object({}) do |var_def, hash|
        hash[var_def['name']] = sample_value_for(var_def)
      end
    end

    def sample_value_for(var_def)
      case var_def['type']
      when 'string' then var_def['default'] || "Sample #{var_def['name']}"
      when 'number' then var_def['default'] || 42
      when 'boolean' then var_def['default'] || true
      when 'array' then var_def['default'] || ['item1', 'item2']
      else var_def['default'] || ''
      end
    end
  end
end
```

### Phase 3: Playground View (Week 2)

**Tasks:**
1. Create playground view with split-pane layout
2. Add code editor with syntax highlighting
3. Implement variable input form
4. Add live preview with AJAX
5. Style with Bootstrap

**Files to Create:**
- `app/views/prompt_tracker/playground/show.html.erb`
- `app/views/prompt_tracker/playground/_editor.html.erb`
- `app/views/prompt_tracker/playground/_preview.html.erb`
- `app/views/prompt_tracker/playground/_variables_form.html.erb`
- `app/assets/javascripts/prompt_tracker/playground.js`
- `app/assets/stylesheets/prompt_tracker/playground.css`

**View Structure:**
```erb
<!-- app/views/prompt_tracker/playground/show.html.erb -->
<div class="playground-container">
  <div class="row">
    <div class="col-12 mb-3">
      <h1>
        <i class="bi bi-code-square"></i> Prompt Playground
        <% if @prompt %>
          - <%= @prompt.name %>
        <% end %>
      </h1>
    </div>
  </div>

  <div class="row playground-main">
    <!-- Left: Template Editor -->
    <div class="col-md-6 playground-editor-pane">
      <%= render 'editor', version: @version %>
    </div>

    <!-- Right: Preview & Variables -->
    <div class="col-md-6 playground-preview-pane">
      <%= render 'variables_form', sample_variables: @sample_variables %>
      <%= render 'preview' %>
    </div>
  </div>

  <!-- Bottom: Actions -->
  <div class="row mt-3">
    <div class="col-12">
      <%= render 'actions', prompt: @prompt %>
    </div>
  </div>
</div>
```

### Phase 4: JavaScript Interactivity (Week 2-3)

**Tasks:**
1. Integrate CodeMirror or Monaco editor
2. Implement debounced live preview
3. Add variable detection
4. Handle errors gracefully
5. Add keyboard shortcuts

**JavaScript Example:**
```javascript
// app/assets/javascripts/prompt_tracker/playground.js
class PromptPlayground {
  constructor() {
    this.editor = null;
    this.previewTimeout = null;
    this.init();
  }

  init() {
    this.initEditor();
    this.bindEvents();
    this.updatePreview();
  }

  initEditor() {
    // Using CodeMirror for syntax highlighting
    this.editor = CodeMirror.fromTextArea(
      document.getElementById('template-editor'),
      {
        mode: 'liquid',
        theme: 'monokai',
        lineNumbers: true,
        lineWrapping: true,
        autofocus: true
      }
    );

    this.editor.on('change', () => this.schedulePreview());
  }

  bindEvents() {
    // Variable inputs trigger preview
    document.querySelectorAll('.variable-input').forEach(input => {
      input.addEventListener('input', () => this.schedulePreview());
    });

    // Save button
    document.getElementById('save-draft-btn')?.addEventListener('click',
      () => this.saveDraft()
    );
  }

  schedulePreview() {
    clearTimeout(this.previewTimeout);
    this.previewTimeout = setTimeout(() => this.updatePreview(), 500);
  }

  async updatePreview() {
    const template = this.editor.getValue();
    const variables = this.collectVariables();

    try {
      const response = await fetch(this.previewUrl(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({ template, variables })
      });

      const data = await response.json();

      if (data.success) {
        this.displayPreview(data.rendered);
        this.updateDetectedVariables(data.variables_detected);
        this.clearErrors();
      } else {
        this.displayError(data.error);
      }
    } catch (error) {
      this.displayError(error.message);
    }
  }

  collectVariables() {
    const variables = {};
    document.querySelectorAll('.variable-input').forEach(input => {
      variables[input.dataset.varName] = input.value;
    });
    return variables;
  }

  displayPreview(rendered) {
    document.getElementById('preview-output').innerHTML =
      this.escapeHtml(rendered);
  }

  displayError(message) {
    document.getElementById('preview-output').innerHTML =
      `<div class="alert alert-danger">${this.escapeHtml(message)}</div>`;
  }

  clearErrors() {
    // Clear any error states
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  csrfToken() {
    return document.querySelector('[name="csrf-token"]').content;
  }

  previewUrl() {
    return document.getElementById('playground-form').dataset.previewUrl;
  }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('template-editor')) {
    new PromptPlayground();
  }
});
```

## 🧪 Testing Strategy

### Unit Tests
- `TemplateRenderer` - Test Liquid syntax, fallback, edge cases
- `PlaygroundController` - Test preview, save, error handling

### Integration Tests
- Full playground workflow
- Variable detection
- Draft version creation

### Manual Testing Checklist
- [ ] Load playground with existing prompt
- [ ] Edit template and see live preview
- [ ] Test Liquid filters (upcase, downcase, etc.)
- [ ] Test Liquid conditionals
- [ ] Test Liquid loops
- [ ] Save as draft version
- [ ] Handle syntax errors gracefully
- [ ] Test with missing variables
- [ ] Test with complex nested objects

## 📝 User Stories

### Story 1: Quick Template Testing
**As a** prompt engineer
**I want to** test template changes without deploying files
**So that** I can iterate quickly on prompt improvements

**Acceptance Criteria:**
- Can edit template in browser
- See rendered output in real-time
- Test with different variable values
- Save successful experiments as drafts

### Story 2: Liquid Syntax Support
**As a** power user
**I want to** use Liquid filters and control flow
**So that** I can create more dynamic prompts

**Acceptance Criteria:**
- Can use filters like `{{ name | upcase }}`
- Can use conditionals like `{% if premium %}...{% endif %}`
- Can use loops like `{% for item in items %}...{% endfor %}`
- Syntax errors are clearly displayed

### Story 3: Variable Management
**As a** prompt engineer
**I want to** easily manage template variables
**So that** I can test different scenarios

**Acceptance Criteria:**
- Variables are auto-detected from template
- Can input sample values for each variable
- Can save variable schemas
- Can load previous variable sets

## 🚀 Future Enhancements

1. **Template Library** - Save and reuse common template snippets
2. **Version Comparison** - Side-by-side diff of template versions
3. **Collaborative Editing** - Multiple users editing simultaneously
4. **Template Validation** - Check for common issues before saving
5. **AI Suggestions** - Suggest improvements to templates
6. **Export/Import** - Export playground sessions as YAML files
7. **History** - Track all playground sessions for a prompt
8. **Keyboard Shortcuts** - Vim/Emacs modes for power users

## 📚 Dependencies

### Ruby Gems
- `liquid` (~> 5.5) - Template engine

### JavaScript Libraries
- CodeMirror or Monaco Editor - Code editing with syntax highlighting
- Lodash - Utility functions (debounce)

### CSS Frameworks
- Bootstrap 5 (already in use)
- Custom playground styles

## 🔒 Security Considerations

1. **Template Injection** - Liquid has built-in XSS protection
2. **Resource Limits** - Set max template size and render timeout
3. **Rate Limiting** - Prevent abuse of preview endpoint
4. **Authorization** - Ensure users can only edit prompts they have access to

## 📊 Success Metrics

- **Adoption Rate** - % of prompt versions created via playground
- **Time to Iterate** - Average time between template edits
- **Error Rate** - % of templates with syntax errors
- **User Satisfaction** - Survey feedback on playground usability
