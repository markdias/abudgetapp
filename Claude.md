always update this claude.md when changes are made.
always ask clarifying questions
do not test the build

## Recent Changes

### Clipboard Copy Feature with Toast Notification - Salary Sorter View (2025-10-30)
Added tap-to-copy clipboard functionality to all currency values in SalarySorterView.swift:
- Tapping any currency value copies the **numeric value only** (without £ symbol) to the clipboard
- Shows an animated toast notification at the top displaying "Copied £X.XX" for 2 seconds
- Includes haptic feedback (light vibration) to confirm successful copy
- Affects the following values:
  - Income totals and individual income amounts
  - Account group total badges
  - Pot totals and individual pot transaction amounts
  - Main Account totals and individual transaction amounts
  - Internal transfer totals and individual amounts
  - Remaining amount footer

Implementation:
- Added `copyToClipboard(_ amount: Double)` helper function
- Copies numeric value only: `String(format: "%.2f", abs(amount))`
- Toast notification with modern gradient capsule design slides down from top
- Uses `UIPasteboard.general.string` for clipboard operations
- Uses `UIImpactFeedbackGenerator` for haptic feedback
- Auto-dismisses toast after 2 seconds with smooth animation
- All currency Text views now have `.onTapGesture` modifiers
- Toast state managed with `@State` properties: `showToast`, `toastMessage`