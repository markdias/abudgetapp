# MyBudget iOS Client

The MyBudget project is a SwiftUI implementation of the budget dashboard that mirrors the behaviour of the existing React front end.

## Architecture

The app uses a collection of domain-focused observable stores to keep local state aligned with the Express API:

| Store | Responsibility |
| --- | --- |
| `AccountsStore` | Owns account lists, account mutations, income/expense creation, and balance resets. |
| `PotsStore` | Tracks pots per account and handles pot mutations. |
| `ScheduledPaymentsStore` | Provides a flattened view of scheduled payments across accounts and pots. |
| `TransferSchedulesStore` | Loads, groups, executes, and deletes transfer schedules. |
| `IncomeSchedulesStore` | Manages salary and recurring income schedules. |
| `SavingsInvestmentsStore` | Loads savings and investment accounts, with exclusion toggles. |
| `ActivityStore` | Builds an activity feed by merging incomes, expenses, and scheduled payments with mark-mode support. |
| `DiagnosticsStore` | Runs a sequential API validation suite that exercises add/execute/delete/reset endpoints. |

The `APIService` is written with `async/await` and provides typed methods for each Express endpoint. Requests are JSON encoded and include robust error propagation through `APIServiceError` and `StatusMessage` types.

All stores broadcast updates so dependent views remain in sync without ad-hoc refresh calls. The environment is wired in `MyBudgetApp`, which bootstraps initial data fetches when the app launches.

## Key UI Features

* **Dashboard (Home)** – Stacked, swipeable account cards with drag-to-reorder, quick actions, search, add menus, and activity feed with mark mode and detail popovers.
* **Transfer Schedules** – Destination grouping, inline execution, delete actions, and a SwiftUI composer sheet.
* **Activity Tab** – Full history view with filters that share the same activity source as the dashboard feed.
* **Budget** – Summaries derived from pots and scheduled payments plus an upcoming payments list.
* **Settings** – Environment configuration, reloads, resets, global execution controls, card reorder flow, and diagnostics launcher.
* **Diagnostics** – Developer QA surface that adds/removes sample data, executes schedules, resets balances, and reports status for each step.

## Environment Configuration

Set the API base URL from the Settings tab. The value is persisted via `UserDefaults`. Default configuration expects the Express server at `http://localhost:3000/`.

## Running the App

1. Update the API base URL if your server differs from the default.
2. Use the dashboard add menu to create accounts, pots, incomes, expenses, and transfer schedules.
3. Visit the Settings tab to trigger diagnostics, resets, or card reordering.

> **Note:** The project targets iOS and requires Xcode 15+ with the Swift 6 toolchain for compilation.

