always update this claude.md when changes are made.
always ask clarifying questions
do not test the build

## Recent Changes

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