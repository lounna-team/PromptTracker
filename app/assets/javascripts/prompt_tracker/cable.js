/**
 * ActionCable Consumer for PromptTracker
 * 
 * This creates a global App.cable object that can be used to subscribe to channels.
 */

(function() {
  // Create the App namespace if it doesn't exist
  window.App || (window.App = {});

  // Create ActionCable consumer
  App.cable = ActionCable.createConsumer();
})();

