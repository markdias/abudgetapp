# MyBudget iOS Client

The MyBudget project is a SwiftUI implementation of the budget dashboard that mirrors the behaviour of the existing React front end.

## Architecture

The app uses a collection of domain-focused observable stores to keep local state aligned with the on-device data store:

| Store | Responsibility |
| --- | --- |
| `AccountsStore` | Owns account lists, account mutations, income/expense creation, and balance resets. |
| `PotsStore` | Tracks pots per account and handles pot mutations. |
| `ScheduledPaymentsStore` | Provides a flattened view of scheduled payments across accounts and pots. |
| `TransferSchedulesStore` | Loads, groups, executes, and deletes transfer schedules. |
| `IncomeSchedulesStore` | Manages salary and recurring income schedules. |
| `SavingsInvestmentsStore` | Loads savings and investment accounts, with exclusion toggles. |
| `ActivityStore` | Builds an activity feed by merging incomes, expenses, and scheduled payments with mark-mode support. |
| `DiagnosticsStore` | Runs an offline validation suite that exercises add/execute/delete/reset operations against local data. |

`APIService` now wraps a local `LocalBudgetStore` actor that reads and writes a JSON snapshot stored in the app's Application Support directory. All requests use `async/await` and map storage errors to `APIServiceError` values for consistent status messaging.

All stores broadcast updates so dependent views remain in sync without ad-hoc refresh calls. The environment is wired in `MyBudgetApp`, which bootstraps initial data fetches when the app launches.

## Key UI Features

* **Dashboard (Home)** – Stacked, swipeable account cards with drag-to-reorder, quick actions, search, add menus, and activity feed with mark mode and detail popovers.
* **Transfer Schedules** – Destination grouping, inline execution, delete actions, and a SwiftUI composer sheet.
* **Activity Tab** – Full history view with filters that share the same activity source as the dashboard feed.
* **Budget** – Summaries derived from pots and scheduled payments plus an upcoming payments list.
* **Settings** – Local storage management (restore sample data, reload, reset balances), card reorder flow, and diagnostics launcher.
* **Diagnostics** – Developer QA surface that adds/removes sample data, executes schedules, resets balances, and reports status for each step.

## Local Persistence

Budget data is saved locally on the device. A bundled sample dataset seeds the app on first launch, and you can restore it at any time from **Settings → Local Storage → Restore Sample Dataset**. Data lives in the app's Application Support directory and no network connectivity is required.

## Running the App

1. Launch the app to load the bundled sample dataset (or restore it from Settings if you have existing data).
2. Use the dashboard add menu to create accounts, pots, incomes, expenses, and transfer schedules.
3. Visit the Settings tab to run diagnostics, reset balances, restore sample data, or start the card reordering flow.

> **Note:** The project targets iOS and requires Xcode 15+ with the Swift 6 toolchain for compilation.

