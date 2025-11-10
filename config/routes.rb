PromptTracker::Engine.routes.draw do
  root to: "prompts#index"

  resources :prompts, only: [:index, :show] do
    member do
      get :analytics
    end

    resources :prompt_versions, only: [:show], path: "versions" do
      member do
        get :compare
      end
    end
  end

  resources :llm_responses, only: [:index, :show], path: "responses"
  resources :evaluations, only: [:index, :show]

  # Analytics & Reports
  namespace :analytics do
    get "/", to: "dashboard#index", as: :root
    get "costs", to: "dashboard#costs"
    get "performance", to: "dashboard#performance"
    get "quality", to: "dashboard#quality"
  end
end
