PromptTracker::Engine.routes.draw do
  root to: "prompts#index"

  # Standalone playground (not tied to a specific prompt)
  resource :playground, only: [:show], controller: 'playground' do
    post :preview, on: :member
    post :save, on: :member
  end

  resources :prompts, only: [:index, :show] do
    member do
      get :analytics
    end

    # Playground for editing existing prompts
    resource :playground, only: [:show], controller: 'playground' do
      post :preview, on: :member
      post :save, on: :member
    end

    resources :prompt_versions, only: [:show], path: "versions" do
      member do
        get :compare
        post :activate
      end

      # Playground for specific version
      resource :playground, only: [:show], controller: 'playground' do
        post :preview, on: :member
        post :save, on: :member
      end

      # Tests nested under prompt versions
      resources :prompt_tests, only: [:index, :new, :create, :show, :edit, :update, :destroy], path: "tests" do
        collection do
          post :run_all
        end
        member do
          post :run
        end
      end
    end

    # A/B tests nested under prompts for creation
    resources :ab_tests, only: [:new, :create], path: "ab-tests"

    # Evaluator configs nested under prompts (for monitoring)
    resources :evaluator_configs, only: [ :index, :show, :create, :update, :destroy ], path: "evaluators"
  end

  # ========================================
  # TESTS SECTION (Blue) - Pre-deployment validation
  # ========================================
  namespace :tests do
    get "/", to: "dashboard#index", as: :root

    # Test runs (for viewing results)
    resources :runs, controller: "prompt_test_runs", only: [:index, :show]
  end

  # ========================================
  # MONITORING SECTION (Green) - Production tracking
  # ========================================
  namespace :monitoring do
    get "/", to: "dashboard#index", as: :root
  end

  # LLM Responses (used by both monitoring and legacy routes)
  resources :llm_responses, only: [:index, :show], path: "responses" do
    collection do
      get :search
    end
  end

  # Evaluations (used by both monitoring and test sections)
  resources :evaluations, only: [:index, :show, :create] do
    collection do
      get :form_template
    end
  end

  # Evaluator config forms (not nested, for AJAX loading)
  resources :evaluator_configs, only: [] do
    collection do
      get :config_form
    end
  end

  # A/B tests at top level for management
  resources :ab_tests, only: [:index, :show, :edit, :update, :destroy], path: "ab-tests" do
    member do
      post :start
      post :pause
      post :resume
      post :complete
      post :cancel
      get :analyze
    end
  end

  # Test runs (legacy, redirects to /tests/runs)
  resources :prompt_test_runs, only: [:index, :show], path: "test-runs"

  # Analytics & Reports
  namespace :analytics do
    get "/", to: "dashboard#index", as: :root
    get "costs", to: "dashboard#costs"
    get "performance", to: "dashboard#performance"
    get "quality", to: "dashboard#quality"
  end
end
