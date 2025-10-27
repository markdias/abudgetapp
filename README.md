# MyBudget iOS Client

The MyBudget project is a SwiftUI implementation of the budget dashboard that mirrors the behaviour of the existing React front end.

## Architecture

The app uses a collection of domain-focused observable stores to keep local state aligned with the on-device data store:

| Store | Responsibility |
| --- | --- |
| `AccountsStore` | Owns account lists, account mutations, income/expense creation, and balance resets. |
| `PotsStore` | Tracks pots per account and handles pot mutations. |
| `ScheduledPaymentsStore` | Provides a flattened view of scheduled payments across accounts and pots. |
| `IncomeSchedulesStore` | Manages salary and recurring income schedules. |
| `SavingsInvestmentsStore` | Loads savings and investment accounts, with exclusion toggles. |
| `ActivityStore` | Builds an activity feed by merging incomes, expenses, transactions, and scheduled payments with mark-mode support. |
| `DiagnosticsStore` | Runs an offline validation suite that exercises add/execute/delete/reset operations against local data. |

All stores work directly with the `LocalBudgetStore` actor that reads and writes a JSON snapshot stored in the app's Application Support directory. Calls are made with `async/await`, and storage failures surface as user-friendly `BudgetDataError` values so the UI can show actionable messages without relying on any remote service.

All stores broadcast updates so dependent views remain in sync without ad-hoc refresh calls. The environment is wired in `MyBudgetApp`, which bootstraps initial data fetches when the app launches.

## Key UI Features

* **Dashboard (Home)** – Stacked, swipeable account cards with drag-to-reorder, quick actions, search, and an add menu for transactions, expenses, and incomes. Activity rows support inline editing for every entry type, including transactions.
* **Income Planner** – Board view for managing recurring income schedules with inline execution and status tracking.
* **Activity Tab** – Full history view with filters that share the same activity source as the dashboard feed.
* **Transfers** – Dedicated hub for planning transfer schedules, queuing expense-driven account transfers, executing income and transfer runs, resetting balances, and sorting salaries into pots. Transfer Schedules builds a queue of transactions that can be executed later from the Transfers tab.
* **Budget** – Summaries derived from pots and scheduled payments plus an upcoming payments list.
* **Settings** – Local storage management (restore sample data, reload, delete-all), card reorder flow, and diagnostics launcher.
* **Diagnostics** – Developer QA surface that adds/removes sample data, executes income schedules, resets balances, and reports status for each step.

## Visual Design

The 2025 refresh reimagines the MyBudget UI with a glassy, neon-accented look that leans into modern iOS design conventions:

* **Immersive gradients** – Every top-level screen floats above a dual-radial background gradient inspired by Monzo's palette. Navigation bars and tab bars inherit blurred materials so transitions feel continuous across tabs.
* **Glass cards** – Dashboards, filter panels, and quick actions live inside reusable `brandCardStyle` containers that blend translucency, neon borders, and soft shadows for depth while keeping content legible in both light and dark modes.
* **Vibrant iconography** – Account cards and workflow shortcuts showcase bold angular gradients, layered blurs, and rounded typography to reinforce hierarchy without relying on heavy borders.
* **Rounded typography** – Headings, badges, and chip controls adopt the rounded SF font variant to echo native iOS 17+ design language and improve scannability on dense financial data.

## Local Persistence

Budget data is saved locally on the device. A bundled sample dataset seeds the app on first launch, and you can restore it at any time from **Settings → Local Storage → Restore Sample Dataset**. Data lives in the app's Application Support directory and no network connectivity is required.

## Running the App

1. Launch the app to load the bundled sample dataset (or restore it from Settings if you have existing data).
2. Use the dashboard add menu to create transactions, expenses, incomes, accounts, and pots. Transactions add money to an account (and optional pot) and appear in Transfer Schedules where they can be queued for execution. Expenses redirect funds between accounts (never pots) and always use positive amounts to represent the cash leaving the source account. Incomes can land directly in a pot.
3. Review or edit any item from the home activity feed or the Activity tab. Swipe actions or detail sheets let you update amounts, day-of-month scheduling, destinations, and associated metadata.
4. Open the Transfers tab to review or update transfer schedules, execute incomes, reset balances, or run the salary sorter. Use the Settings tab for diagnostics, restoring the sample dataset, and card reordering.

> **Note:** The project targets iOS and requires Xcode 15+ with the Swift 6 toolchain for compilation.

