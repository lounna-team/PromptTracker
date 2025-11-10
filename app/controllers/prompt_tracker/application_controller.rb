module PromptTracker
  class ApplicationController < ActionController::Base
    include PromptTracker::Concerns::BasicAuthentication
  end
end
