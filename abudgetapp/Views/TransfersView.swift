import SwiftUI

struct TransfersView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var potsStore: PotsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore

    private var totalScheduledPayments: Int {
        scheduledPaymentsStore.items.count
    }

    private var totalPots: Int {
        potsStore.potsByAccount.values.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Plan and execute movements of money between your main accounts and pots. Use the shortcuts below to manage schedules, run transfers, or rebalance after payday.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)

                    if totalScheduledPayments > 0 {
                        Label("Active schedules: \(totalScheduledPayments)", systemImage: "calendar")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if totalPots > 0 {
                        Label("Managed pots: \(totalPots)", systemImage: "tray.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    let queuedCount = accountsStore.transferQueue.count
                    if queuedCount > 0 {
                        Label("Queued transfers: \(queuedCount)", systemImage: "arrow.right.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Transfer Operations") {
                    NavigationLink(destination: ManageTransferSchedulesView()) {
                        Label("Manage Transfer Schedules", systemImage: "calendar.badge.clock")
                    }

                    NavigationLink(destination: ExecuteTransferSchedulesView()) {
                        Label("Execute Transfer Schedules", systemImage: "play.rectangle")
                    }
                }

                Section("Utilities") {
                    NavigationLink(destination: ResetBalancesView()) {
                        Label("Reset Balances", systemImage: "arrow.counterclockwise.circle")
                    }

                    NavigationLink(destination: SalarySorterView()) {
                        Label("Salary Sorter", systemImage: "chart.pie")
                    }
                }
            }
            .navigationTitle("Transfers")
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Manage Transfer Schedules

struct ManageTransferSchedulesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore

    @State private var selectedAccountId: Int?

    private var accounts: [Account] { accountsStore.accounts }

    private var sourceAccount: Account? {
        guard let selectedAccountId else { return accounts.first }
        return accountsStore.account(for: selectedAccountId)
    }

    private var transferCandidates: [TransferScheduleItem] {
        guard let account = sourceAccount else { return [] }
        return accountsStore.transferCandidates(fromAccountId: account.id)
    }

    private var scheduledTransfers: [TransferScheduleItem] {
        accountsStore.transferQueue.sorted { lhs, rhs in
            if lhs.fromAccountName == rhs.fromAccountName {
                return lhs.destinationDisplayName.localizedCaseInsensitiveCompare(rhs.destinationDisplayName) == .orderedAscending
            }
            return lhs.fromAccountName.localizedCaseInsensitiveCompare(rhs.fromAccountName) == .orderedAscending
        }
    }

    var body: some View {
        Form {
            Section("Source Account") {
                if accounts.isEmpty {
                    Label("Add an account to begin scheduling transfers.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Account", selection: Binding<Int?>(
                        get: { selectedAccountId ?? accounts.first?.id },
                        set: { selectedAccountId = $0 }
                    )) {
                        ForEach(accounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            Section("Transfer Groups") {
                if transferCandidates.isEmpty {
                    ContentUnavailableView {
                        Label("No transfer candidates", systemImage: "calendar")
                    } description: {
                        Text("Assign destinations to expenses for this account to build a schedule.")
                    }
                } else {
                    ForEach(transferCandidates) { item in
                        TransferCandidateRow(
                            item: item,
                            isQueued: accountsStore.isTransferQueued(item),
                            toggleAction: { toggleCandidate(item) }
                        )
                    }
                }
            }

            if !scheduledTransfers.isEmpty {
                Section("Scheduled Transfers") {
                    ForEach(scheduledTransfers) { item in
                        TransferQueueRow(item: item, removeAction: { accountsStore.dequeueTransfer(item) })
                    }
                    Button(role: .destructive) {
                        accountsStore.clearTransferQueue()
                    } label: {
                        Label("Clear Scheduled Transfers", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("Quick Management") {
                NavigationLink("Manage Incomes") { ManageIncomesView() }
                NavigationLink("Manage Transfers") { ManageTransfersDetailView() }
                NavigationLink("Manage Transactions") { ManageTransactionsView() }
                NavigationLink("Manage Expenses") { ManageExpensesView() }
            }
        }
        .navigationTitle("Manage Schedules")
        .onAppear {
            if selectedAccountId == nil {
                selectedAccountId = accounts.first?.id
            }
        }
    }

    private func toggleCandidate(_ item: TransferScheduleItem) {
        if accountsStore.isTransferQueued(item) {
            accountsStore.dequeueTransfer(item)
        } else {
            accountsStore.enqueueTransfer(item)
        }
    }
}

private struct TransferCandidateRow: View {
    let item: TransferScheduleItem
    let isQueued: Bool
    let toggleAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.destinationDisplayName)
                        .font(.headline)
                    if let subtitle = item.destinationSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .fontWeight(.semibold)
            }

            if !item.contexts.isEmpty {
                Text("Covers \(item.expenseCount) expense\(item.expenseCount == 1 ? "" : "s"): \(item.expenseSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: toggleAction) {
                Label(isQueued ? "Remove from Schedule" : "Add to Schedule",
                      systemImage: isQueued ? "checkmark.circle.fill" : "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isQueued ? .green : .accentColor)
        }
        .padding(.vertical, 6)
    }
}

private struct TransferQueueRow: View {
    let item: TransferScheduleItem
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.destinationDisplayName)
                        .font(.headline)
                    if let subtitle = item.destinationSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("From: \(item.fromAccountName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .fontWeight(.semibold)
            }

            if !item.contexts.isEmpty {
                Text(item.expenseSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive, action: removeAction) {
                Label("Remove", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Execute Transfer Schedules

struct ExecuteTransferSchedulesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore

    @State private var executingIncome = false
    @State private var executingTransfers = false
    @State private var executingQueuedTransfers = false

    private var pendingIncomeSchedules: [IncomeSchedule] {
        incomeStore.schedules.filter { !$0.isCompleted }
    }

    private var pendingPayments: [ScheduledPaymentsStore.ScheduledPaymentContext] {
        scheduledPaymentsStore.items.filter { $0.payment.isCompleted != true }
    }

    private var queuedTransfers: [TransferScheduleItem] { accountsStore.transferQueue }

    private var queuedTotal: Double {
        queuedTransfers.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List {
            Section("Transfer Queue") {
                if queuedTransfers.isEmpty {
                    Label("No transfers queued for execution.", systemImage: "tray")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(queuedTransfers) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.destinationDisplayName)
                                .font(.subheadline)
                            Text("From: \(item.fromAccountName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                Spacer()
                                Text("\(item.expenseCount) expense\(item.expenseCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(queuedTotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .fontWeight(.semibold)
                    }
                }

                Button {
                    Task {
                        executingQueuedTransfers = true
                        defer { executingQueuedTransfers = false }
                        await accountsStore.executeQueuedTransfers()
                    }
                } label: {
                    Label("Execute Transfer Queue", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(executingQueuedTransfers || queuedTransfers.isEmpty)
            }

            Section("Income") {
                if pendingIncomeSchedules.isEmpty {
                    Label("All income schedules are up to date.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pendingIncomeSchedules) { schedule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.description)
                                .font(.subheadline)
                            Text("Account #\(schedule.accountId) • \(schedule.company)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(schedule.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                Spacer()
                                Text(schedule.isCompleted ? "Completed" : "Pending")
                                    .font(.caption)
                                    .foregroundStyle(schedule.isCompleted ? .green : .orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button {
                    Task {
                        executingIncome = true
                        defer { executingIncome = false }
                        await incomeStore.executeAll()
                        await accountsStore.loadAccounts()
                    }
                } label: {
                    Label("Execute Income", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(executingIncome || pendingIncomeSchedules.isEmpty)
            }

            Section("Transfers & Expenses") {
                if pendingPayments.isEmpty {
                    Label("Nothing to execute right now.", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pendingPayments) { context in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.payment.name)
                                .font(.subheadline)
                            Text(context.potName ?? context.accountName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(context.payment.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                Spacer()
                                Text(context.payment.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button {
                    Task {
                        executingTransfers = true
                        defer { executingTransfers = false }
                        await accountsStore.loadAccounts()
                    }
                } label: {
                    Label("Execute Transfers", systemImage: "arrow.left.arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(executingTransfers || pendingPayments.isEmpty)
            }

            Section("Detailed Execution") {
                NavigationLink("Execute Income") { ExecuteIncomeView() }
                NavigationLink("Execute Transfers") { ExecuteTransfersView() }
                NavigationLink("Execute Transactions") { ExecuteTransactionsView() }
                NavigationLink("Execute Expenses") { ExecuteExpensesView() }
            }
        }
        .navigationTitle("Execute Schedules")
    }
}

// MARK: - Quick Management Detail Screens

struct ManageIncomesView: View {
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore

    var body: some View {
        List {
            Section("Scheduled Incomes") {
                if incomeStore.schedules.isEmpty {
                    ContentUnavailableView {
                        Label("No income schedules", systemImage: "tray")
                    } description: {
                        Text("Create a schedule from an account to see it listed here.")
                    }
                } else {
                    ForEach(incomeStore.schedules) { schedule in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(schedule.description)
                                .font(.headline)
                            Text(schedule.company)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(schedule.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Manage Incomes")
    }
}

struct ManageTransfersDetailView: View {
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore

    var body: some View {
        List {
            Section("Transfers") {
                let transfers = scheduledPaymentsStore.items.filter { ($0.payment.type ?? "").lowercased().contains("transfer") }
                if transfers.isEmpty {
                    Label("No transfer schedules available.", systemImage: "arrow.left.arrow.right")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transfers) { context in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(context.payment.name)
                                .font(.headline)
                            Text(context.potName ?? context.accountName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(context.payment.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Manage Transfers")
    }
}

struct ManageTransactionsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore

    var body: some View {
        List {
            Section("Recent Transactions") {
                if accountsStore.transactions.isEmpty {
                    ContentUnavailableView {
                        Label("No transactions", systemImage: "list.bullet")
                    } description: {
                        Text("Add transactions from the dashboard or import data to see them listed here.")
                    }
                } else {
                    ForEach(accountsStore.transactions) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.name)
                                .font(.headline)
                            HStack {
                                Text(record.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(record.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Manage Transactions")
    }
}

struct ManageExpensesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore

    private var expenses: [Expense] {
        accountsStore.accounts.flatMap { $0.expenses ?? [] }
    }

    @ViewBuilder
    private var expensesSectionContent: some View {
        if expenses.isEmpty {
            Label("No expenses configured.", systemImage: "creditcard")
                .foregroundStyle(.secondary)
        } else {
            ForEach(expenses, id: \.id) { expense in
                VStack(alignment: .leading, spacing: 6) {
                    Text(expense.description)
                        .font(.headline)
                    HStack(spacing: 8) {
                        if let toAccountId = expense.toAccountId {
                            Text("To Account #\(toAccountId)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let toPot = expense.toPotName {
                            Text("Pot: \(toPot)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Day: \(expense.date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 6)
            }
        }
    }

    var body: some View {
        List {
            Section {
                expensesSectionContent
            } header: {
                Text("Recurring Expenses")
            }
        }
        .navigationTitle("Manage Expenses")
    }
}

// MARK: - Execute Detail Screens

struct ExecuteIncomeView: View {
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore

    var body: some View {
        List {
            Section("Income Schedules") {
                ForEach(incomeStore.schedules) { schedule in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedule.description)
                            .font(.headline)
                        Text(schedule.company)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(schedule.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            Spacer()
                            Text(schedule.isCompleted ? "Completed" : "Pending")
                                .font(.caption)
                                .foregroundStyle(schedule.isCompleted ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Execute Income")
    }
}

struct ExecuteTransfersView: View {
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore

    var body: some View {
        List {
            Section("Transfers") {
                let transfers = scheduledPaymentsStore.items.filter { ($0.payment.type ?? "").lowercased().contains("transfer") }
                ForEach(transfers) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.payment.name)
                            .font(.headline)
                        Text(context.potName ?? context.accountName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.payment.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Execute Transfers")
    }
}

struct ExecuteTransactionsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore

    var body: some View {
        List {
            Section("Transactions") {
                ForEach(accountsStore.transactions) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.name)
                            .font(.headline)
                        HStack {
                            Text(record.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            Spacer()
                            Text(record.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Execute Transactions")
    }
}

struct ExecuteExpensesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore

    private var expenses: [Expense] {
        accountsStore.accounts.flatMap { $0.expenses ?? [] }
    }

    var body: some View {
        List {
            Section {
                ForEach(expenses, id: \.id) { expense in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.description)
                            .font(.headline)
                        HStack(spacing: 8) {
                            if let toAccountId = expense.toAccountId {
                                Text("To Account #\(toAccountId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let toPot = expense.toPotName {
                                Text("Pot: \(toPot)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Day: \(expense.date)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text("Expenses")
            }
        }
        .navigationTitle("Execute Expenses")
    }
}

// MARK: - Utilities

struct ResetBalancesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore

    @State private var isResetting = false
    @State private var showConfirmation = false

    var body: some View {
        Form {
            Section {
                Text("Resetting balances will zero out all account balances and reload schedules. Use this after moving funds externally to realign the budget with actual bank balances.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Section {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Label("Reset Balances", systemImage: "arrow.counterclockwise.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isResetting)
            }
        }
        .navigationTitle("Reset Balances")
        .alert("Reset all balances?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                Task {
                    isResetting = true
                    defer { isResetting = false }
                    await accountsStore.resetBalances()
                    await incomeStore.load()
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

struct SalarySorterView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var potsStore: PotsStore

    @State private var selectedAccountId: Int?
    @State private var allocation: [String: Double] = [:]

    private var accounts: [Account] { accountsStore.accounts }

    private var potsForSelection: [Pot] {
        guard let selectedId = selectedAccountId else { return [] }
        return potsStore.potsByAccount[selectedId] ?? []
    }

    var body: some View {
        Form {
            Section("Select Account") {
                Picker("Account", selection: Binding<Int?>(
                    get: { selectedAccountId ?? accounts.first?.id },
                    set: { newValue in
                        selectedAccountId = newValue
                        recomputeAllocation()
                    }
                )) {
                    ForEach(accounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                if potsForSelection.isEmpty {
                    Text("Create pots for the selected account to plan your salary distribution.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(potsForSelection, id: \.id) { pot in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(pot.name)
                            }
                            Spacer()
                            TextField("Amount", value: Binding<Double>(
                                get: { allocation[pot.name, default: 0] },
                                set: { allocation[pot.name] = $0 }
                            ), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                        }
                    }
                }
            } header: {
                Text("Allocation")
            }

            if !allocation.isEmpty {
                Section("Summary") {
                    let total = allocation.values.reduce(0, +)
                    Label("Total allocated: \(total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))", systemImage: "sum")
                    Button("Save Allocation") {
                        // Placeholder action for persistence integration
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Salary Sorter")
        .onAppear {
            if selectedAccountId == nil {
                selectedAccountId = accounts.first?.id
            }
            recomputeAllocation()
        }
    }

    private func recomputeAllocation() {
        guard let selectedId = selectedAccountId else {
            allocation = [:]
            return
        }
        guard let pots = potsStore.potsByAccount[selectedId] else {
            allocation = [:]
            return
        }
        allocation = Dictionary(uniqueKeysWithValues: pots.map { ($0.name, 0) })
    }
}

#Preview {
    TransfersView()
        .environmentObject(AccountsStore())
        .environmentObject(PotsStore(accountsStore: AccountsStore()))
        .environmentObject(IncomeSchedulesStore(accountsStore: AccountsStore()))
        .environmentObject(ScheduledPaymentsStore(accountsStore: AccountsStore()))
}
