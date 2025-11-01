# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Guidelines

1. **Always update this claude.md when significant changes are made** – Keep architectural descriptions in sync with implementation.
2. **Always ask clarifying questions** – Confirm intent before major refactors or feature additions.
3. **Do not test the build** – Avoid running Xcode builds during development (user manages testing).
4. **Use absolute code references** – When discussing code, use format `file.swift:123` or markdown links like `[file.swift:123](path/file.swift#L123)`.

## Build & Run Commands

**Build the app:**
```bash
xcodebuild build -scheme abudgetapp -configuration Debug
```

**Run on simulator:**
```bash
xcodebuild build-for-testing -scheme abudgetapp -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Run UI tests:**
```bash
xcodebuild test -scheme abudgetapp -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Run specific test:**
```bash
xcodebuild test -scheme abudgetapp -testProductName abudgetappUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Clean build:**
```bash
xcodebuild clean -scheme abudgetapp
```

> **Note:** The project targets **iOS 15+** and requires **Xcode 15+** with Swift 6 toolchain. There are currently **no unit tests**—only a basic smoke test in abudgetappUITests that verifies the home tab is visible on launch.

## Codebase Architecture

### High-Level Design

The app follows **MVVM + Actor-based concurrency** with SwiftUI:

```
Views (SwiftUI)
  ↓ (subscribe via @EnvironmentObject)
Store Objects (ObservableObject with @Published)
  ↓ (call async methods)
LocalBudgetStore (Actor for thread-safe persistence)
  ↓ (read/write)
JSON file (~Library/Application Support/abudgetapp/budget.json)
```

**Key Pattern**: Stores are @Published @EnvironmentObjects that delegate to LocalBudgetStore, which handles all data mutations safely on a dedicated actor queue.

### Directory Structure

```
abudgetapp/
├── abudgetappApp.swift              # Entry point, app bootstrap, auto-processing logic
├── ContentView.swift                # Root TabView navigation
│
├── Views/                           # SwiftUI UI (12 files)
│   ├── HomeView.swift               # Dashboard, transactions, manual processing (largest: 153 KB)
│   ├── TransfersView.swift          # Transfer & balance reduction management
│   ├── ProcessedTransactionsView.swift # Auto-process config & logs
│   ├── TransferSchedulesView.swift  # Schedule creation
│   ├── IncomeSchedulesView.swift    # Income schedule management
│   ├── SalarySorterView.swift       # Salary analysis with clipboard copy
│   ├── ExecutionManagementView.swift # Event deletion & log cleanup
│   ├── ExecutionLogsView.swift      # Collapsible log display
│   ├── BudgetView.swift, ActivitiesView.swift, SettingsView.swift
│   └── FormSheets.swift             # Reusable form components
│
├── Models/                          # Data models (6 files, 96 KB)
│   ├── BudgetDataModels.swift       # Core: Account, Pot, TransactionRecord, TransactionEvent, etc.
│   ├── Models.swift, Budget.swift, Transaction.swift, etc.
│
├── Stores/                          # ViewModels (6 files, 152 KB)
│   ├── AccountsStore.swift          # Master store (22.5 KB) – coordinates other stores
│   ├── PotsStore.swift, IncomeSchedulesStore.swift, TransferSchedulesStore.swift
│   ├── ScheduledPaymentsStore.swift, DiagnosticsStore.swift
│
├── Services/                        # Data layer (3 files, 90 KB)
│   ├── LocalBudgetStore.swift       # Core actor, 2,112 lines – ALL data reads/writes happen here
│   ├── ExecutionLogsManager.swift   # Execution log tracking
│   └── BudgetDataError.swift        # Error types
│
├── Utilities/
│   ├── ModernTheme.swift            # Design system
│   └── JSONDocument.swift           # Document handling
│
└── Assets.xcassets/                 # Images & colors
```

### LocalBudgetStore – The Data Layer

**Location**: [LocalBudgetStore.swift](abudgetapp/Services/LocalBudgetStore.swift) (2,112 lines)

**What It Does**:
- **Singleton actor** – Thread-safe, handles ALL data mutations
- **Persistence** – Reads/writes JSON to `~/Library/Application Support/abudgetapp/budget.json`
- **Business logic** – Processes scheduled transactions, executes income/transfer schedules, tracks events

**Key Methods** (async/throwing):
- `currentAccounts()`, `currentTransactions()`, `currentIncomeSchedules()`, `currentTransferSchedules()` – Read ops
- `addAccount()`, `addTransaction()`, `addIncomeSchedule()`, `addTransferSchedule()` – Create
- `processScheduledTransactions()` – Main processing loop for scheduled & yearly transactions
- `executeIncomeSchedule()`, `executeTransferSchedule()` – Execute schedules with event tracking
- `deleteTransactionEvent()` – Event cleanup (deletes transaction if last event removed)
- `markYearlyTransactionAsReady()` – Reset yearly transaction for next year
- `applyMonthlyReduction()` – Monthly balance reduction

**Internal State** (BudgetState):
- accounts, incomeSchedules, transferSchedules, transactions
- processedTransactionLogs, balanceReductionLogs
- ID counters (nextAccountId, nextPotId, nextTransactionEventId, etc.)

**Key Detail**: All data is JSON-encoded with ISO8601 dates. The actor ensures **no race conditions** when multiple stores call methods concurrently.

### Store Objects Pattern

Each store is a `@MainActor` class that:
1. Owns a @Published property (accounts, transactions, etc.)
2. Calls async methods on LocalBudgetStore
3. Updates @Published after mutations
4. Broadcasts changes so views re-render

Example from AccountsStore:
```swift
@MainActor
final class AccountsStore: ObservableObject {
    @Published var accounts: [Account] = []
    private let store: LocalBudgetStore

    func addAccount(_ submission: AccountSubmission) async {
        let result = await store.addAccount(submission)
        // Update @Published
        accounts = await store.currentAccounts()
    }
}
```

Stores are injected as @EnvironmentObject in views:
```swift
@EnvironmentObject private var accountsStore: AccountsStore
```

### Core Data Models

**BudgetDataModels.swift** contains:

- **Account**: id, name, balance, accountType (checking/savings/credit card/etc.), pots, scheduled_payments
- **Pot**: id, name, balance, excludeFromReset flag
- **TransactionRecord**: Kind (scheduled/creditCardCharge/creditCardPayment/yearly), name, vendor, amount, dates, linked accounts/pots, **events array for execution history**, executionCount
- **TransactionEvent** (NEW): id, executedAt (ISO8601), amount – tracks when/how much was executed
- **IncomeSchedule / TransferSchedule**: Recurring definitions, day-of-month, amount, active/completed state, event tracking
- **ProcessedTransactionLog / BalanceReductionLog**: Audit trail

**Key Fields**:
- Yearly transactions: `yearlyDate` (format "dd-MM-yyyy"), `isCompleted` (true once processed in year)
- Credit card linked: `linkedCreditAccountId`, `transferScheduleId`, `events` array
- Auto-processing settings: Stored in @AppStorage in abudgetappApp.swift

## Key Features & How They Work

### 1. Auto-Processing System

**Locations**: [abudgetappApp.swift](abudgetapp/abudgetappApp.swift), [ProcessedTransactionsView.swift](abudgetapp/Views/ProcessedTransactionsView.swift)

Three automation levels:

| Feature | Trigger | Config Storage |
|---------|---------|-----------------|
| **Auto-Process on Launch** | App opens | `autoProcessTransactionsEnabled` |
| **Auto-Process on Day** | Specific day/time monthly | `autoProcessOnDayEnabled`, `autoProcessDay` (1-31), `autoProcessHour` (0-23), `autoProcessMinute` (0-55 by 5-min increments) |
| **Auto-Reduce Balances** | App becomes active | `autoReduceBalancesEnabled` |

**bootstrap() method** (abudgetappApp.swift):
- Runs on app launch
- Checks `autoProcessTransactionsEnabled` and calls processScheduledTransactions()
- Checks `shouldAutoProcessToday()` for day-based auto-process (prevents duplicate same-day runs)
- Shows notification with count

### 2. Yearly Transactions

**Date Format**: "dd-MM-yyyy" (e.g., "25-12-2025")

**Processing**:
- Matches only day-month, ignores year
- Marks as `isCompleted = true` after first processing in year
- Reset via `markYearlyTransactionAsReady()` to process again next year

**Execution**: In processScheduledTransactions(), yearly loop processes yearly transactions if:
- kind == .yearly
- shouldProcessYearlyTransaction() returns true (day-month matches today)
- isCompleted != true

### 3. Credit Card Payment Tracking

**Automatic Detection**: Accounts with `isCredit = true`

**Behavior**:
- First execution/process → Creates TransactionRecord with kind `.creditCardPayment` or `.creditCardCharge` + initial TransactionEvent
- Subsequent executions → Appends new event to existing transaction (no new transaction)
- Transfers to credit cards **never mark completed**, allowing re-execution
- Visual distinction: cyan for payments, indigo for charges

**Event Storage**:
- TransactionRecord.events: [TransactionEvent]?
- Each event tracks executedAt (ISO8601) and amount
- executionCount computed property returns event count

### 4. Event History & Deletion

All transactions and schedules track execution events in an `events` array.

**Deletion** (deleteTransactionEvent):
- Remove specific event by ID
- If last event: Delete entire transaction and clear transfer link
- Updates views automatically

### 5. Clipboard Copy Feature

**Location**: [SalarySorterView.swift](abudgetapp/Views/SalarySorterView.swift)

Tapping any currency value:
1. Copies numeric value only (no £ symbol)
2. Shows toast notification "Copied £X.XX" for 2 seconds
3. Triggers haptic feedback

## Important Implementation Details

### Data Model Conventions

- **Optional fields**: All new tracking fields (events, yearlyDate, linkedCreditAccountId, etc.) are optional for backward compatibility
- **ID Counters**: LocalBudgetStore maintains nextTransactionEventId counter for unique event IDs
- **Date Formats**: ISO8601 for timestamps, "dd-MM-yyyy" for yearly dates
- **Computed Properties**: executionCount, isCredit, account type checks

### Thread Safety & Concurrency

- **LocalBudgetStore is an actor** – All state mutations serialized automatically
- **Stores run on @MainActor** – Safe to update @Published properties
- **No locks needed** – Swift's actor isolation handles synchronization

### Backward Compatibility

- All new fields are optional (`?`)
- Existing data without events/yearly/linked fields still works
- No migrations needed (defaults to nil)

### Error Handling

- BudgetDataError enum for all data errors
- Stores catch errors and set @Published statusMessage for UI
- No silent failures – all errors surface as user-friendly messages

## Recent Changes (2025-10-31)

### Settings Refactoring & Auto-Process Day Feature
- Moved automation toggles from Settings to their feature views (better UX)
- Implemented "Auto-Process on Day" in ProcessedTransactionsView with day/time picker
- Added "Process on App Launch" toggle to processingCard
- Added "Reduce on App Active" toggle to balance reduction UI
- Settings persist via @AppStorage

### Yearly Transactions (2025-10-30)
- New `.yearly` transaction kind
- Stores full date in "dd-MM-yyyy" format
- Processes on day-month match (date-agnostic)
- Manual "Reset for Next Year" button to clear `isCompleted` flag
- Event history tracks all executions

### Credit Card Payment Tracking (2025-10-30)
- Auto-detection of credit card accounts
- Immediate transaction creation when transfer linked to credit card
- Event appending (no transaction duplication) on subsequent executions
- TransactionEvent model for execution tracking
- Cyan/indigo color coding for visual distinction

### Clipboard Copy & Toast (2025-10-30)
- Tap currency values to copy numeric-only to clipboard
- Animated toast notification
- Haptic feedback confirmation
- Affects all currency displays in SalarySorterView

## Common Tasks

**Adding a New Feature**:
1. Define models in BudgetDataModels.swift (add optional fields for new data)
2. Add logic to LocalBudgetStore (implement the processing/mutation)
3. Update relevant Store (add @Published property if needed, call LocalBudgetStore methods)
4. Update Views (add UI elements, observe store changes)
5. Update this CLAUDE.md with feature description

**Adding UI to Existing Feature**:
1. Locate the relevant View file (likely HomeView, TransfersView, or ProcessedTransactionsView)
2. Find the existing card/section
3. Add new SwiftUI elements (state, form fields, buttons)
4. Wire up to existing store methods

**Debugging Data Issues**:
1. Check LocalBudgetStore logic (data transformation happens here)
2. Verify model fields match JSON structure (check persistence)
3. Use Diagnostics tab to inspect current state
4. Check accountsStore @Published properties in Xcode preview/debugger

**Performance Optimization**:
1. HomeView.swift is the largest file (153 KB) – consider splitting into sub-views
2. ProcessedTransactionsView loading can be optimized with lazy loading
3. No unit tests exist – add tests for LocalBudgetStore business logic
