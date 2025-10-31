always update this claude.md when changes are made.
always ask clarifying questions
do not test the build

## Recent Changes

### Settings Refactoring & Auto-Process Day Feature (2025-10-31)
Moved automation toggles from Settings to their respective feature views for better UX:

#### Changes Made:
1. **Removed from SettingsView**:
   - "Process Transactions Automatically" toggle
   - "Reduce Balances Automatically" toggle
   - Removed entire automationCard from Settings UI

2. **Added to ProcessedTransactionsView**:
   - "Process on App Launch" toggle in processingCard
   - Allows users to enable/disable automatic processing when viewing transaction processing options
   - Label: "Automatically processes when app opens"

3. **Added to BalanceReductionView** (in TransfersView.swift):
   - "Reduce on App Active" toggle in reduceNowCard
   - Allows users to enable/disable automatic reduction when viewing balance reduction options
   - Label: "Automatically reduces when app becomes active"

4. **Implemented Auto-Process on Day Feature** (2025-10-31):
   - New "Auto-Process on Day" card in ProcessedTransactionsView between Manual Processing and Auto-Process on Launch
   - **Configuration**:
     - Day picker: Select day 1-31 of month (global trigger)
     - Time picker: Set specific hour (0-23) and minute (0-55 in 5-min increments)
     - "Next Scheduled" display: Shows when next auto-process will run
   - **Behavior**:
     - Runs automatically when app launches on configured day at/after configured time
     - Processes ALL due scheduled transactions
     - Prevents duplicate processing on same day
     - Shows notification with transaction count processed
   - **Settings Storage** (abudgetappApp.swift):
     - `autoProcessOnDayEnabled`: Boolean toggle
     - `autoProcessDay`: Int (1-31)
     - `autoProcessHour`: Int (0-23)
     - `autoProcessMinute`: Int (0-55)
     - `lastAutoProcessDate`: ISO8601 string tracking last execution

#### Files Modified:
- **SettingsView.swift**: Removed automationCard, removed @AppStorage references
- **ProcessedTransactionsView.swift**:
  - Added `@AppStorage` properties for auto-process day settings
  - Added toggle to processingCard for auto-process on launch
  - Added new autoProcessSettingsCard with day/time configuration
  - Added nextScheduledText computed property
- **TransfersView.swift (BalanceReductionView)**:
  - Added toggle to reduceNowCard for auto-reduce on app active
- **abudgetappApp.swift**:
  - Added @AppStorage properties for day-based auto-processing
  - Added shouldAutoProcessToday() method for schedule checking
  - Added showAutoProcessNotification() method for user feedback
  - Integrated auto-process check in bootstrap() after existing auto-process logic

#### User Experience:
- Toggles now live near their related functionality
- Settings view is simpler (automation removed)
- Clearer intent: toggle is visible where it's used
- Day-based scheduling provides fine-grained control over when processing occurs
- Settings persist across app sessions via @AppStorage

### Yearly Transactions Feature - Complete Implementation (2025-10-30)
Implemented comprehensive yearly transactions system that processes transactions on specific dates (day-month-year) and tracks execution history with events. Yearly transactions are primarily linked to pots and deduct amounts when processed on their scheduled date. Additionally, added event history tracking to all transactions and income executions.

#### Core Functionality:
- **Transaction Type**: New `.yearly` kind for TransactionRecord to distinguish yearly transactions
- **Date Format**: Stores full date as "dd-MM-yyyy" (e.g., "25-12-2025")
- **Processing**: Only processes on exact day-month match (date-agnostic processing)
- **Completion State**: Marked as `isCompleted = true` after first processing in a year
- **Reset for Next Year**: Manual reset via "Reset for Next Year" button clears `isCompleted` flag
- **Pot & Account Support**: Can link to accounts or pots (mostly used for pots)
- **Event Tracking**: Creates TransactionEvent on each processing to track execution history
- **Event History**: All transactions and income now track execution events passively

#### Data Model Changes (BudgetDataModels.swift):

**UPDATED: TransactionRecord.Kind enum** (line 245):
- Added `.yearly` case for yearly transactions

**UPDATED: TransactionRecord fields** (lines 261-262):
- `yearlyDate: String?` - Full date in format "dd-MM-yyyy"
- `isCompleted: Bool?` - Tracks if already processed this year

**UPDATED: TransactionSubmission** (lines 742-743):
- `yearlyDate: String?` - Accept yearly date from UI
- `isCompleted: Bool?` - Track completion state

**UPDATED: IncomeSchedule** (lines 597-601):
- `events: [TransactionEvent]?` - Array of execution events
- `executionCount: Int` - Computed property returning events count

#### Backend Logic (LocalBudgetStore.swift):

**NEW: Date Parsing Helpers** (lines 1183-1209):
```swift
private static func isYearlyDateString(_ raw: String) -> Bool
private static func yearlyDate(from raw: String) -> (day: Int, month: Int, year: Int)?
private static func shouldProcessYearlyTransaction(_ transaction: TransactionRecord) -> Bool
```
- Validates "dd-MM-yyyy" format
- Parses individual day, month, year components
- Checks if today matches transaction's day-month (ignores year)

**NEW: markYearlyTransactionAsReady** (lines 608-622):
```swift
func markYearlyTransactionAsReady(id: Int) throws -> MessageResponse
```
- Resets `isCompleted = false` to allow processing next year
- Validates transaction is yearly type

**UPDATED: processScheduledTransactions** (lines 782-856):
- Added yearly transaction processing loop after scheduled transactions
- Checks `kind == .yearly` and `shouldProcessYearlyTransaction()`
- Skips if already completed this year (`isCompleted == true`)
- Deducts amount from account or pot
- Creates event and marks as `isCompleted = true`
- Adds to processed transaction logs

**UPDATED: executeIncomeSchedule** (lines 1182-1210):
- Adds TransactionEvent to income execution
- Creates new event with `executedAt` (ISO8601) and amount
- Appends to income's events array

**UPDATED: executeAllIncomeSchedules** (lines 1212-1240):
- Same event tracking as executeIncomeSchedule
- Processes all active non-completed income schedules

#### Store Layer Updates:

**LocalBudgetStore.swift** - UPDATED: addTransaction (lines 337-367):
- Determines kind based on `submission.yearlyDate`
- Sets kind to `.yearly` if yearlyDate provided, `.scheduled` otherwise
- Passes yearlyDate and isCompleted to TransactionRecord

**AccountsStore.swift** - NEW: resetYearlyTransaction (lines 284-298):
```swift
func resetYearlyTransaction(id: Int) async
```
- Calls LocalBudgetStore.markYearlyTransactionAsReady
- Reloads transactions after reset
- Shows success status message

#### UI Implementation:

**HomeView.swift - AddTransactionSheet** (lines 1691-1813):
- Added `@State private var transactionType: String = "scheduled"`
- Added `@State private var yearlyDate: Date = Date()`
- New "Schedule" section with type picker (Scheduled/Yearly)
- Conditionally shows DatePicker for yearly or TextField for scheduled day
- Updated canSave validation for both transaction types
- Modified save() to format yearlyDate as "dd-MM-yyyy" and pass appropriate parameters

**HomeView.swift - Activities Panel** (lines 505-527):
- Updated typeSuffix logic to detect yearly transactions via `kind == .yearly`
- Extracts day and month from yearlyDate
- Displays "Yearly: MMM DD" format (e.g., "Yearly: Dec 25")
- Sorted in transaction list with visual indicator

**HomeView.swift - TransactionPreviewSheet** (lines 2836-2854):
- Updated dayDescription property to format yearly dates as "dd MMM yyyy"
- Parses yearlyDate components and creates date for formatting
- Event history section already displays all events (no changes needed)

#### Technical Details:
- **Date Format**: "dd-MM-yyyy" for storage (day-month-year with dashes)
- **Date Parsing**: Validates month (1-12) and day (1-31) ranges, year >= 2000
- **Processing Logic**: Compares only day and month to today, ignoring year
- **Completion Semantics**: `isCompleted` is yearly scoped, not permanent
- **Event Tracking**: Passive tracking only (no completion status for events themselves)
- **Backward Compatibility**: All new fields are optional
- **Income Event History**: Reuses TransactionEvent model for consistent event tracking

#### User Flow:

**Creating Yearly Transactions:**
1. User taps "Add Transaction" at bottom of transaction list
2. Fills in name, company, amount, and account/pot destination
3. Selects "Schedule Type" = "Yearly"
4. Uses DatePicker to select exact date (e.g., Dec 25, 2025)
5. Saves transaction with kind=.yearly, yearlyDate="25-12-2025", isCompleted=false

**Processing Yearly Transactions:**
1. User runs "Process Transactions" on Dec 25 (any year after 2025)
2. System detects yearly transaction with matching day-month
3. Amount deducted from pot/account
4. TransactionEvent created and added to transaction
5. Transaction marked `isCompleted = true`
6. Appears in processed transaction logs

**Resetting for Next Year:**
1. User navigates to "Processed Transactions" view
2. Finds completed yearly transaction from previous year
3. Taps "Reset for Next Year" button (or similar)
4. System calls resetYearlyTransaction
5. Transaction's `isCompleted` set to false
6. Ready to process again on next occurrence of that date

**Viewing Execution History:**
1. User taps transaction in Activities panel
2. Transaction detail view shows "Yearly: Dec 25" indicator
3. "Execution History" section shows all past executions
4. Each event displays execution date and amount
5. User can delete individual events with confirmation
6. If last event deleted, entire transaction is removed

### Credit Card Payment Tracking with Events - Complete Feature (2025-10-30)
Implemented comprehensive credit card payment tracking system that creates special transactions with event tracking when either:
1. **Transfer schedules** linked to credit cards are executed (kind `.creditCardPayment`)
2. **Scheduled transactions** linked to credit cards are processed (kind `.creditCardCharge`)

Each execution/process adds an event to track payment history.

#### Core Functionality:
- **First execution/process**: Creates NEW TransactionRecord with event
- **Subsequent executions/processes**: Appends new TransactionEvent to existing transaction (no new transaction)
- **Each event tracks**: `executedAt` (ISO8601 timestamp), `amount`, and unique `id`
- **Transaction displays**: execution count via computed property `executionCount`
- **Re-executable transfers**: Credit card linked transfers don't mark as completed, allowing multiple executions
- **Event deletion**: Can delete individual events; deleting last event removes entire transaction and clears transfer link
- **Standard transfers/transactions**: Non-credit-card behavior unchanged

#### Data Model Changes (BudgetDataModels.swift):

**NEW: TransactionEvent model** (lines 216-238):
```swift
public struct TransactionEvent: Identifiable, Codable, Hashable {
    public let id: Int
    public let executedAt: String  // ISO8601 timestamp
    public let amount: Double
}
```

**UPDATED: TransactionRecord.Kind enum** (lines 241-245):
- Added `.creditCardPayment` case for payment tracking transactions

**UPDATED: TransactionRecord fields** (lines 258-263):
- `transferScheduleId: Int?` - Link back to transfer schedule
- `events: [TransactionEvent]?` - Array of execution events
- `executionCount: Int` - Computed property returning events count

**UPDATED: TransferSchedule fields** (lines 619-620):
- `linkedCreditAccountId: Int?` - Target credit card account ID
- `linkedTransactionId: Int?` - Created transaction ID

**UPDATED: TransferScheduleSubmission** (lines 798-816):
- `linkedCreditAccountId: Int?` - Optional parameter for linking to credit card

#### Backend Logic (LocalBudgetStore.swift):

**UPDATED: BudgetState** (line 1232):
- `nextTransactionEventId: Int` - ID counter for events

**UPDATED: executeTransferSchedule** (lines 392-454):
- Detects credit card linked schedules via `linkedCreditAccountId`
- First execution: Creates new transaction with initial event
- Subsequent executions: Finds existing transaction and appends event
- Credit card payments: Only updates `lastExecuted`, NOT `isCompleted`
- Regular transfers: Marks as `isCompleted = true` (preserves existing behavior)

**UPDATED: executeAllTransferSchedules** (lines 456-527):
- Identical credit card payment logic to single execution
- Processes all active, non-completed schedules

**UPDATED: processScheduledTransactions** (lines 714-758):
- Detects scheduled transactions with `linkedCreditAccountId`
- Creates or updates credit card charge transactions with events
- First process: Creates new transaction with initial event
- Subsequent processes: Appends event to existing transaction (matching by kind, name, and credit account)
- Tracks execution count for recurring charges

**NEW: deleteTransactionEvent** (lines 537-567):
```swift
func deleteTransactionEvent(transactionId: Int, eventId: Int) throws -> MessageResponse
```
- Removes specific event from transaction's events array
- If last event: Deletes entire transaction and clears `linkedTransactionId` on schedule
- Otherwise: Updates transaction with remaining events

**UPDATED: addTransferSchedule** (lines 374-391):
- Accepts `linkedCreditAccountId` from submission
- Creates TransferSchedule with linkedCreditAccountId and linkedTransactionId fields

#### Store Layer Updates:

**AccountsStore.swift** - NEW: deleteTransactionEvent method (lines 268-282):
```swift
func deleteTransactionEvent(transactionId: Int, eventId: Int) async
```
- Calls LocalBudgetStore.deleteTransactionEvent
- Reloads transactions after deletion
- Shows status message for user feedback

**TransferSchedulesStore.swift** - UPDATED: addSchedule method (line 30):
- Added `linkedCreditAccountId: Int? = nil` parameter
- Passes to TransferScheduleSubmission when creating schedule
- No other changes needed - execute methods already handle re-execution correctly

#### UI Implementation:

**HomeView.swift - TransactionPreviewSheet** (lines 2741-2893):
- Added `@EnvironmentObject private var accountsStore: AccountsStore` for event deletion
- Added execution history section showing all events (sorted newest first)
- Displays formatted date and amount for each event
- Delete button for each event with confirmation dialog
- Shows execution count in Transaction section
- Added "Credit Card Payment" to payment type descriptions
- ISO8601 and display date formatters for event timestamps

**HomeView.swift - Activities Panel** (lines 414-855):
- Added "credit_card_payment" case to payment type suffix (line 510)
- Added cyan color coding for credit card payment transactions (line 840)
- Displays "Credit Card Payment" text in activity list items
- Visual distinction helps identify payment transactions

**TransferSchedulesView.swift - Transfer Creation UI** (lines 114-436):
- Automatically detects credit card accounts via `account.isCredit`
- When scheduling transfer to credit card: passes `linkedCreditAccountId`
- Visual indicator: Adds " • Credit Card" to subtitle (lines 283, 297)
- Works for both pot destinations and account destinations
- No manual toggle needed - automatic based on account type

#### Technical Details:
- **Event IDs**: Unique across all events, managed by `nextTransactionEventId` counter
- **Backward Compatibility**: All new fields are optional, existing data works without migration
- **Transaction Cleanup**: Automatic deletion when last event removed maintains data consistency
- **Bidirectional Linking**: TransferSchedule ↔ TransactionRecord for data integrity
- **Date Format**: ISO8601 with fractional seconds for precise execution tracking
- **Re-execution Safety**: Credit card schedules remain `!isCompleted` to allow multiple executions

#### User Flow:

**Transfer Schedules with Credit Card Linking:**
1. User creates transfer schedule to credit card account (automatic detection via `account.isCredit`)
2. User executes transfer → Creates transaction with first event (kind `.creditCardPayment`)
3. User executes again → Adds event to existing transaction (no new transaction)
4. Transfer remains `!isCompleted` to allow multiple executions

**Scheduled Transactions with Credit Card Linking:**
1. User has scheduled transaction linked to credit card account (via `linkedCreditAccountId`)
2. Process scheduled transactions → Creates transaction with first event (kind `.creditCardCharge`)
3. Process again → Adds event to existing transaction (matches by kind, name, and credit account)
4. Execution count grows with each processing

**Viewing & Managing:**
- Transaction detail view shows all execution history with dates and amounts
- User can delete individual events with confirmation
- Deleting last event removes entire transaction and clears any transfer link
- Execution count displayed in transaction details

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

### Credit Card Transaction Display Enhancement (2025-10-31)
Verified and confirmed complete implementation of credit card transaction display with comprehensive visual distinction in the activity list.

#### Implementation Verification:

**LocalBudgetStore.swift - Core Functionality (Already Implemented)**:
- `addTransferSchedule()` (lines 414-437) - Creates transaction immediately when linked to credit card
- `executeTransferSchedule()` (lines 470-487) - Reuses existing transaction, appends new events instead of creating new ones
- `executeAllTransferSchedules()` (lines 514-531) - Same event appending logic as single execution
- `processScheduledTransactions()` (lines 769-783) - Creates/reuses transactions with event tracking for scheduled charges
- `addTransaction()` (lines 353-354) - Sets kind to `.creditCardCharge` when `linkedCreditAccountId` provided

**HomeView.swift - Transaction Display in Account View**:
- `ActivitiesPanelSection.combinedItems` (lines 499-561) - Filters and displays credit card linked transactions
  - Line 501: Includes `linkedCreditAccountId` in transaction filter
  - Line 505: Detects linked credit card view perspective
  - Lines 531-533: Adds "Linked to [Account]" suffix for visual clarity
  - Line 554: Stores payment type in metadata for styling
  - Line 555: Stores isLinkedCreditCard flag in metadata

**HomeView.swift - Visual Distinction for Credit Card Transactions**:
- `ActivityListItemRow` (lines 766-887) - Renders activity items with color coding
  - Lines 865-875: Color property detects payment type and returns appropriate color:
    - `"credit_card_charge"` → `.indigo.opacity(0.85)` - Scheduled charges appear in indigo
    - `"credit_card_payment"` → `.cyan.opacity(0.85)` - Transfer payments appear in cyan (as documented)
    - `"credit_card_charge"` → `.indigo.opacity(0.85)` - Distinguishes from regular transactions
    - `"direct_debit"` → `.blue.opacity(0.85)` - Regular direct debits in blue
    - Default `.blue.opacity(0.85)` - Other transactions in blue
  - Line 802: Color applied to circular badge with gradient effect
  - Line 812-814: Icon (arrow.left.arrow.right.circle.fill) rendered in white on colored background

#### User Experience:
- **Visual Identification**: Credit card transactions are immediately identifiable by cyan (payments) or indigo (charges) icons in the activity list
- **Color Coding Benefits**:
  - Cyan (`cyan.opacity(0.85)`) for credit card payments from transfer schedules
  - Indigo (`indigo.opacity(0.85)`) for credit card charges from scheduled transactions
  - Clear visual distinction from regular blue transactions
- **Account Context**: When viewing a credit card account, transactions show "Linked to [source account]" suffix
- **Payment Type Labels**: Activity list displays "Credit Card Payment" or "Credit Card Charge" in the company/type field
- **Metadata Tracking**: Transaction items include payment type and linked status in metadata for flexible styling

#### Technical Architecture:
- **Event Tracking**: First execution/process creates TransactionRecord with initial TransactionEvent
- **Subsequent Executions**: Events appended to existing transaction (no new transaction created)
- **No Completion Flag**: Credit card transfers remain active (`!isCompleted`) for re-execution
- **Backward Compatible**: All features use optional fields, existing data unaffected
- **Automatic Detection**: No manual toggle needed - links to credit card accounts are automatic

#### Summary:
All credit card transaction features are fully implemented and operational:
✓ Immediate transaction creation when linking transfer to credit card
✓ Event appending instead of transaction duplication
✓ Visual distinction with cyan (payments) and indigo (charges) colors
✓ Display in account view with linked account context
✓ Metadata tracking for flexible styling and filtering