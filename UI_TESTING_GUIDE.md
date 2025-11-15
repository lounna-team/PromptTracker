# UI Testing Guide

## 🎨 Phase 3 Complete - UI Components Ready!

The evaluator system now has a full web UI! Here's how to test it.

---

## 🚀 Quick Start

### 1. Start the Rails Server

```bash
bin/rails server
```

Navigate to: `http://localhost:3000/prompt_tracker`

### 2. Set Up Test Data

Run the example script to create a prompt with evaluators:

```bash
bin/rails console
load 'examples/multi_evaluator_setup.rb'
```

This creates:
- A prompt named "customer_support_greeting"
- 3 configured evaluators (length, keyword, format)
- A sample response with evaluations

---

## 📋 UI Features to Test

### Feature 1: Evaluator Configuration UI

**Location:** Prompt Show Page → "Auto-Evaluation" Card

**URL:** `/prompt_tracker/prompts/:id`

**What to Test:**

1. **View Configured Evaluators**
   - Navigate to a prompt (e.g., "customer_support_greeting")
   - Scroll to the "Auto-Evaluation" card
   - You should see:
     - ✅ Aggregation strategy badge (e.g., "Weighted Average")
     - ✅ Table of configured evaluators
     - ✅ Priority, weight, mode, dependency columns
     - ✅ Visual progress bars for weights
     - ✅ Normalized weight percentages

2. **Add a New Evaluator**
   - Click "Add Evaluator" button
   - Modal should open with form
   - Select an evaluator from dropdown (e.g., "Length Validator")
   - Description should appear below dropdown
   - Fill in:
     - Enabled: ✅ (checked)
     - Execution Mode: Sync or Async
     - Priority: 1
     - Weight: 0.25 (25%)
     - Dependency: None (or select existing evaluator)
     - Min Dependency Score: 80
     - Configuration: `{"min_length": 50, "max_length": 500}`
   - Click "Add Evaluator"
   - Should redirect back to prompt page
   - New evaluator should appear in table

3. **Edit an Evaluator**
   - Click "Edit" button on an evaluator
   - Currently shows alert (placeholder)
   - TODO: Implement edit modal

4. **Remove an Evaluator**
   - Click "Remove" button on an evaluator
   - Confirm deletion
   - Evaluator should be removed from list

5. **Weight Distribution**
   - Check "Total Weight" at bottom of card
   - Should show sum of all enabled evaluator weights
   - For weighted average strategy, shows normalization message

### Feature 2: Evaluation Breakdown Scorecard

**Location:** Response Show Page → "Evaluation Results" Card

**URL:** `/prompt_tracker/responses/:id`

**What to Test:**

1. **Overall Score Display**
   - Large score number (e.g., "87.5/100")
   - Progress bar with color coding:
     - Green (≥80): Passes Quality Check
     - Yellow (60-79): Needs Review
     - Red (<60): Below Standard
   - Aggregation strategy shown (e.g., "Weighted Average")
   - Quality check badge

2. **Individual Evaluation Cards**
   - Each evaluation shown in a card
   - Card border color matches score (green/yellow/red)
   - Header shows:
     - Evaluator name
     - Evaluator type (Human/Automated/LLM Judge)
     - Score (large number)
     - Weight percentage (for weighted average)
   - Body shows:
     - Progress bar with score
     - Feedback text (if present)
     - Criteria breakdown (if present)
     - Timestamp

3. **Criteria Breakdown**
   - For evaluations with criteria_scores
   - Shows mini progress bars for each criterion
   - Color coded (green/yellow/red)
   - Score displayed next to each bar

4. **Weakest/Strongest Areas**
   - Two alert boxes at bottom
   - Red alert: Weakest area with score
   - Green alert: Strongest area with score

5. **No Evaluations State**
   - If no evaluations exist:
     - Shows empty state with icon
     - Message about auto-evaluation
     - Link to configure evaluators (if none configured)

---

## 🧪 Test Scenarios

### Scenario 1: Configure Evaluators for a New Prompt

1. Navigate to prompts list: `/prompt_tracker/prompts`
2. Click on any prompt
3. Scroll to "Auto-Evaluation" card
4. Click "Add Evaluator"
5. Add 3 evaluators:
   - **Length Check** (weight: 0.20, sync, priority: 1)
   - **Keyword Check** (weight: 0.30, sync, priority: 2)
   - **Format Check** (weight: 0.50, sync, priority: 3, depends on: length_check)
6. Verify all 3 appear in table
7. Check total weight = 1.0
8. Verify normalized weights shown

### Scenario 2: Create Response and View Auto-Evaluation

1. In Rails console:
   ```ruby
   prompt = PromptTracker::Prompt.find_by(name: "customer_support_greeting")
   version = prompt.active_version
   
   response = PromptTracker::LlmResponse.create!(
     prompt_version: version,
     rendered_prompt: "Hello {{customer_name}}, how can I help you today?",
     response_text: "Hello! I'm here to assist you with any questions.",
     provider: "openai",
     model: "gpt-4",
     status: "success",
     response_time_ms: 500,
     tokens_total: 15,
     cost_usd: 0.0001
   )
   
   puts "Response ID: #{response.id}"
   ```

2. Navigate to response: `/prompt_tracker/responses/:id`
3. Verify:
   - Overall score is calculated
   - Individual evaluations are shown
   - Criteria breakdowns are visible
   - Weakest/strongest areas are identified

### Scenario 3: Test Dependency Logic

1. Configure two evaluators:
   - **Evaluator A** (no dependency, priority: 1)
   - **Evaluator B** (depends on A, min score: 90, priority: 2)

2. Create a response that scores low on Evaluator A (e.g., 50)

3. Verify:
   - Evaluator A runs and creates evaluation
   - Evaluator B does NOT run (dependency not met)
   - Only 1 evaluation shown on response page

4. Create another response that scores high on Evaluator A (e.g., 95)

5. Verify:
   - Both evaluators run
   - 2 evaluations shown on response page

### Scenario 4: Test Different Aggregation Strategies

1. In Rails console:
   ```ruby
   prompt = PromptTracker::Prompt.find_by(name: "customer_support_greeting")
   
   # Test simple average
   prompt.update!(score_aggregation_strategy: "simple_average")
   ```

2. Create a response and view it

3. Verify overall score is simple average (weights ignored)

4. Change to minimum:
   ```ruby
   prompt.update!(score_aggregation_strategy: "minimum")
   ```

5. Create another response

6. Verify overall score is the minimum of all evaluations

---

## ✅ Expected Results

### Evaluator Config UI
- ✅ Clean, organized table of evaluators
- ✅ Visual weight distribution with progress bars
- ✅ Easy to add/remove evaluators
- ✅ Clear indication of dependencies
- ✅ Sync/async mode badges
- ✅ Enabled/disabled status

### Evaluation Breakdown UI
- ✅ Large, prominent overall score
- ✅ Color-coded quality indicators
- ✅ Individual evaluation cards with details
- ✅ Criteria breakdown for each evaluation
- ✅ Weakest/strongest area highlights
- ✅ Responsive layout (2 columns on desktop)

---

## 🐛 Known Issues / TODOs

1. **Edit Evaluator** - Currently shows alert, needs full implementation
2. **Drag-and-Drop Priority** - Would be nice to reorder evaluators visually
3. **Real-time Updates** - Async evaluations don't update UI automatically
4. **Config Validation** - JSON config field needs better validation/UI
5. **Evaluator Templates** - Pre-filled configs for common use cases

---

## 📸 Screenshots to Take

When testing, capture screenshots of:

1. Evaluator configuration card (with 3+ evaluators)
2. Add evaluator modal (filled out)
3. Evaluation breakdown with overall score
4. Individual evaluation cards showing criteria
5. Weakest/strongest areas
6. Empty state (no evaluators configured)
7. Empty state (no evaluations yet)

---

## 🎯 Success Criteria

- [ ] Can add evaluators via UI
- [ ] Can remove evaluators via UI
- [ ] Weights are displayed correctly
- [ ] Dependencies are shown clearly
- [ ] Overall score is calculated and displayed
- [ ] Individual evaluations are shown in cards
- [ ] Criteria breakdowns are visible
- [ ] Color coding works (green/yellow/red)
- [ ] Empty states are helpful
- [ ] UI is responsive on mobile

---

## 🚀 Next Steps After Testing

1. **Report any bugs** you find
2. **Suggest UI improvements** (layout, colors, wording)
3. **Test on different browsers** (Chrome, Firefox, Safari)
4. **Test on mobile devices**
5. **Consider accessibility** (screen readers, keyboard navigation)

---

## 💡 Tips

- Use browser dev tools to inspect elements
- Check console for JavaScript errors
- Test with different data (many evaluators, few evaluators, no evaluators)
- Try edge cases (very long feedback, many criteria, etc.)
- Test with different aggregation strategies

Happy testing! 🎉

