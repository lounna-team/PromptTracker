Rails.application.routes.draw do
  mount PromptTracker::Engine => "/prompt_tracker"
end
