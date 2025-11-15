# Modal Z-Index Fix

## 🐛 Problem

The Add Evaluator and Edit Evaluator modals were appearing **behind** the modal backdrop (`<div class="modal-backdrop fade show"></div>`), making them inaccessible and unclickable.

### Symptoms
- Modal appears visually but is grayed out
- Cannot click on any form fields
- Cannot close the modal
- Backdrop is blocking all interaction

### Root Cause
Bootstrap 5 uses the following default z-index values:
- `.modal-backdrop`: `z-index: 1050`
- `.modal`: `z-index: 1050`

When both have the same z-index, the stacking order becomes unpredictable, and the backdrop can appear on top of the modal content.

---

## ✅ Solution

Added explicit z-index values to ensure proper stacking order:

```css
/* Ensure modals appear above backdrop */
#addEvaluatorModal,
#editEvaluatorModal {
  z-index: 1060 !important;
}

/* Ensure backdrop is below modals */
.modal-backdrop {
  z-index: 1050 !important;
}

/* Ensure modal content is clickable */
#addEvaluatorModal .modal-content,
#editEvaluatorModal .modal-content {
  position: relative;
  z-index: 1061 !important;
}
```

### Z-Index Hierarchy
1. **Modal Content**: `z-index: 1061` (highest - always on top)
2. **Modal Container**: `z-index: 1060` (middle)
3. **Backdrop**: `z-index: 1050` (lowest - behind everything)

---

## 📁 Files Modified

- ✅ `app/views/prompt_tracker/prompts/_evaluator_modals.html.erb`
  - Added `<style>` block at the top with z-index fixes
  - Applied to both `#addEvaluatorModal` and `#editEvaluatorModal`

---

## 🧪 How to Test

### Test Add Evaluator Modal

1. **Start the Rails server:**
   ```bash
   bin/rails server
   ```

2. **Navigate to a prompt:**
   ```
   http://localhost:3000/prompt_tracker/prompts/:id
   ```

3. **Click "Add Evaluator" button**
   - ✅ Modal should appear clearly visible
   - ✅ Backdrop should be behind the modal (darker background)
   - ✅ Modal content should be bright and clickable

4. **Test interactions:**
   - ✅ Click on the "Evaluator" dropdown - should open
   - ✅ Type in the "Priority" field - should accept input
   - ✅ Click "Cancel" button - modal should close
   - ✅ Click outside modal (on backdrop) - modal should close

### Test Edit Evaluator Modal

1. **On the same prompt page, click "Edit" on an existing evaluator**
   - ✅ Edit modal should appear clearly visible
   - ✅ All form fields should be populated with current values
   - ✅ All fields should be clickable and editable

2. **Test interactions:**
   - ✅ Change the "Weight" value
   - ✅ Change the "Priority" value
   - ✅ Click "Save Changes" - should submit and reload page
   - ✅ Click "Cancel" - modal should close without saving

### Visual Verification

**Before Fix:**
```
┌─────────────────────────────┐
│   Modal (z-index: 1050)     │  ← Behind backdrop (not clickable)
│   [Grayed out, unclickable] │
└─────────────────────────────┘
┌─────────────────────────────┐
│ Backdrop (z-index: 1050)    │  ← On top (blocking clicks)
│ [Dark overlay]              │
└─────────────────────────────┘
```

**After Fix:**
```
┌─────────────────────────────┐
│ Backdrop (z-index: 1050)    │  ← Behind modal
│ [Dark overlay]              │
└─────────────────────────────┘
┌─────────────────────────────┐
│   Modal (z-index: 1060)     │  ← On top (clickable)
│   Content (z-index: 1061)   │
│   [Bright, fully clickable] │
└─────────────────────────────┘
```

---

## 🔍 Debugging Tips

If the modal is still not accessible:

1. **Check browser console for errors:**
   ```javascript
   // Open DevTools (F12) and check Console tab
   ```

2. **Inspect the modal element:**
   ```javascript
   // In Console, run:
   document.getElementById('addEvaluatorModal').style.zIndex
   // Should return "1060"
   ```

3. **Inspect the backdrop:**
   ```javascript
   // In Console, run:
   document.querySelector('.modal-backdrop').style.zIndex
   // Should return "1050"
   ```

4. **Check computed styles:**
   - Right-click on modal → Inspect
   - Look at "Computed" tab in DevTools
   - Find `z-index` property
   - Should show `1060` or `1061`

5. **Clear browser cache:**
   ```bash
   # Hard refresh
   Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)
   ```

---

## 🎯 Success Criteria

✅ Modal appears on top of backdrop  
✅ All form fields are clickable  
✅ Dropdown menus work correctly  
✅ Modal can be closed via Cancel button  
✅ Modal can be closed by clicking backdrop  
✅ Form submission works correctly  

---

## 📚 Related Documentation

- Bootstrap 5 Modal Documentation: https://getbootstrap.com/docs/5.3/components/modal/
- CSS Z-Index: https://developer.mozilla.org/en-US/docs/Web/CSS/z-index
- Stacking Context: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_positioned_layout/Understanding_z-index/Stacking_context

---

## ✨ Additional Notes

- The `!important` flag is necessary to override Bootstrap's default styles
- The fix is scoped to specific modal IDs to avoid affecting other modals in the application
- The modal content gets an extra z-index boost (1061) to ensure it's always on top
- This fix is compatible with Bootstrap 5.3 and should work with future versions

---

**Status:** ✅ **FIXED**  
**Date:** 2025-01-12  
**Tested:** Pending user verification

