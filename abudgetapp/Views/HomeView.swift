import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var potsStore: PotsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @EnvironmentObject private var savingsStore: SavingsInvestmentsStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore

    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var showingAddAccount = false
    @State private var showingAddPot = false
    @State private var showingAddIncome = false
    @State private var showingAddExpense = false
    @State private var showingAddTransaction = false
    @State private var showingPotsManager = false
    @State private var showingSavings = false
    @State private var showingIncomeSchedules = false
    @State private var showingCardReorder = false
    @State private var showingDiagnostics = false
    @State private var selectedActivity: ActivityItem?
    @State private var selectedAccountId: Int? = nil
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = JSONDocument()
    @State private var showingDeleteAllConfirm = false
    @State private var selectedPotContext: PotEditContext? = nil
    @State private var transactionSourceAccountId: Int? = nil

    private let cardSpacing: CGFloat = 72

    private var filteredAccounts: [Account] {
        guard !searchText.isEmpty else { return accountsStore.accounts }
        return accountsStore.accounts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var reorderableAccounts: [Account] {
        // Show all accounts including savings/investments in the card stack
        filteredAccounts
    }

    private var totalBalance: Double {
        accountsStore.accounts.reduce(0) { $0 + $1.balance }
    }

    private var todaysSpending: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return activityStore.activities
            .filter { $0.category == .expense && Calendar.current.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.amount }
    }

    private var filteredActivities: [ActivityItem] {
        // Start from store-level category filtering
        var items = activityStore.filteredActivities

        // If an account is selected, show only that account's items
        if let selectedId = selectedAccountId,
           let account = accountsStore.accounts.first(where: { $0.id == selectedId }) {
            items = items.filter { $0.accountName == account.name }
        }

        // Apply text search if present
        if searchText.isEmpty { return items }
        return items.filter { activity in
            activity.title.localizedCaseInsensitiveContains(searchText) ||
            activity.accountName.localizedCaseInsensitiveContains(searchText) ||
            (activity.potName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if reorderableAccounts.isEmpty {
                        ContentUnavailableView(
                            "No Accounts",
                            systemImage: "creditcard",
                            description: Text("Use the add menu to create your first account.")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        StackedAccountDeck(
                            accounts: reorderableAccounts,
                            selectedAccountId: $selectedAccountId,
                            searchText: searchText,
                            spacing: cardSpacing,
                            onReorder: handleReorder,
                            onAddPot: { _ in showingAddPot = true },
                            onAddTransaction: { account in
                                transactionSourceAccountId = account.id
                                showingAddTransaction = true
                            },
                            onManageCards: { showingCardReorder = true },
                            onDelete: { account in
                                Task { await accountsStore.deleteAccount(id: account.id) }
                            }
                        )
                    }
                    ActivityFeedSection(
                        activityStore: activityStore,
                        activities: filteredActivities,
                        selectedActivity: $selectedActivity,
                        onViewAll: { selectedTab = 1 }
                    )

                    PotsPanelSection(
                        accounts: accountsStore.accounts,
                        potsByAccount: potsStore.potsByAccount,
                        onTapPot: { account, pot in
                            selectedPotContext = PotEditContext(account: account, pot: pot)
                        },
                        onDeletePot: { account, pot in
                            Task { await potsStore.deletePot(accountId: account.id, potName: pot.name) }
                        }
                    )

                    QuickActionsView(
                        onManagePots: { showingPotsManager = true },
                        onSavings: { showingSavings = true },
                        onIncome: { showingIncomeSchedules = true },
                        onReorder: { showingCardReorder = true },
                        onDiagnostics: { showingDiagnostics = true },
                        onSettings: { selectedTab = 2 }
                    )

                    BalanceSummaryCard(totalBalance: totalBalance, todaysSpending: todaysSpending)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refreshAllData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh data")
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { activityStore.isMarking.toggle() }) {
                        Image(systemName: activityStore.isMarking ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .help("Toggle mark mode")

                    Menu {
                        Button("Add Transaction") {
                            transactionSourceAccountId = nil
                            showingAddTransaction = true
                        }
                        Button("Add Expense", action: { showingAddExpense = true })
                        Button("Add Income", action: { showingAddIncome = true })
                        Divider()
                        Button("Add Account", action: { showingAddAccount = true })
                        Button("Add Pot", action: { showingAddPot = true })
                        Divider()
                        Button("Import Data (JSON)") { showingImporter = true }
                        Button("Export Data (JSON)") { Task { await exportAllData() } }
                        Button(role: .destructive) { showingDeleteAllConfirm = true } label: {
                            Text("Delete All Data")
                        }
                        Divider()
                        Button("Run Diagnostics", action: { showingDiagnostics = true })
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        do {
                            let accessed = url.startAccessingSecurityScopedResource()
                            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                            let data = try Data(contentsOf: url)
                            _ = try await LocalBudgetStore.shared.importStateData(data)
                            await refreshAllAfterImport()
                            accountsStore.statusMessage = StatusMessage(title: "Import", message: "Budget restored from file", kind: .success)
                        } catch let error as LocalBudgetStore.StoreError {
                            let dataError = error.asBudgetDataError
                            accountsStore.statusMessage = StatusMessage(title: "Import Failed", message: dataError.localizedDescription, kind: .error)
                        } catch {
                            let dataError = BudgetDataError.unknown(error)
                            accountsStore.statusMessage = StatusMessage(title: "Import Failed", message: dataError.localizedDescription, kind: .error)
                        }
                    }
                case .failure(let error):
                    print("Importer error: \(error)")
                }
            }
            .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json, defaultFilename: "budget_state") { result in
                if case .failure(let error) = result { print("Export failed: \(error)") }
            }
            .alert("Delete All Data?", isPresented: $showingDeleteAllConfirm) {
                Button("Delete", role: .destructive) { Task { await deleteAllData() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently erase all accounts, pots, expenses, incomes, and schedules. This cannot be undone.")
            }
            .toolbar { // chip to clear selected account when active
                if let selectedId = selectedAccountId,
                   let account = accountsStore.accounts.first(where: { $0.id == selectedId }) {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            selectedAccountId = nil
                        } label: {
                            Label("Showing: \(account.name) — Clear", systemImage: "xmark.circle.fill")
                        }
                        .font(.footnote)
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AccountFormView(isPresented: $showingAddAccount)
            }
            .sheet(isPresented: $showingAddPot) {
                PotFormView(isPresented: $showingAddPot)
            }
            .sheet(isPresented: $showingAddIncome) {
                IncomeFormView(isPresented: $showingAddIncome)
            }
            .sheet(isPresented: $showingAddExpense) {
                ExpenseFormView(isPresented: $showingAddExpense)
            }
            .sheet(isPresented: $showingAddTransaction) {
                TransactionFormView(isPresented: $showingAddTransaction, defaultFromAccountId: transactionSourceAccountId)
            }
            .sheet(isPresented: $showingPotsManager) {
                PotsManagementView(isPresented: $showingPotsManager)
            }
            .sheet(isPresented: $showingSavings) {
                SavingsInvestmentsView(isPresented: $showingSavings)
            }
            .sheet(isPresented: $showingIncomeSchedules) {
                IncomeSchedulesBoardView(isPresented: $showingIncomeSchedules)
            }
            .sheet(isPresented: $showingCardReorder) {
                CardReorderView(isPresented: $showingCardReorder)
            }
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticsRunnerView(isPresented: $showingDiagnostics)
            }
            .sheet(item: $selectedPotContext) { context in
                PotEditorSheet(context: context)
            }
            .sheet(item: $selectedActivity) { activity in
                ActivityEditorSheet(activity: activity)
            }
        }
    }

    private func refreshAllData() {
        Task {
            await accountsStore.loadAccounts()
            await savingsStore.load()
            await incomeStore.load()
        }
    }

    private func refreshAllAfterImport() async {
        await accountsStore.loadAccounts()
        await incomeStore.load()
        await savingsStore.load()
    }

    private func exportAllData() async {
        do {
            let data = try await LocalBudgetStore.shared.exportStateData()
            exportDocument = JSONDocument(data: data)
            showingExporter = true
            accountsStore.statusMessage = StatusMessage(title: "Export", message: "Budget exported", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            accountsStore.statusMessage = StatusMessage(title: "Export Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            accountsStore.statusMessage = StatusMessage(title: "Export Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    private func deleteAllData() async {
        do {
            _ = try await LocalBudgetStore.shared.clearAll()
            await refreshAllAfterImport()
            accountsStore.statusMessage = StatusMessage(title: "Delete", message: "All data cleared", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            accountsStore.statusMessage = StatusMessage(title: "Delete Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            accountsStore.statusMessage = StatusMessage(title: "Delete Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    private func handleReorder(from sourceIndex: Int, to destinationIndex: Int) {
        let target = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        Task {
            await accountsStore.reorderAccounts(fromOffsets: IndexSet(integer: sourceIndex), toOffset: max(target, 0))
        }
    }
}

// MARK: - Summary Card

private struct BalanceSummaryCard: View {
    let totalBalance: Double
    let todaysSpending: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Balance")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("£\(String(format: "%.2f", totalBalance))")
                .font(.system(size: 36, weight: .bold))

            HStack {
                Label("Spent today", systemImage: "sun.max")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("£\(String(format: "%.2f", todaysSpending))")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 6)
    }
}

// MARK: - Stacked Account Deck

private struct StackedAccountDeck: View {
    let accounts: [Account]
    @Binding var selectedAccountId: Int?
    let searchText: String
    let spacing: CGFloat
    let onReorder: (Int, Int) -> Void
    let onAddPot: (Account) -> Void
    let onAddTransaction: (Account) -> Void
    let onManageCards: () -> Void
    let onDelete: (Account) -> Void

    @State private var draggingAccount: Account?
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .top) {
            // When a card is selected, show only that card; otherwise show the whole stack
            let visibleAccounts: [Account] = {
                if let id = selectedAccountId, let a = accounts.first(where: { $0.id == id }) {
                    return [a]
                }
                return accounts
            }()

            ForEach(Array(visibleAccounts.enumerated()), id: \.element.id) { index, account in
                AccountCardView(
                    account: account,
                    onTap: {
                        if selectedAccountId == account.id {
                            selectedAccountId = nil
                        } else {
                            selectedAccountId = account.id
                        }
                    },
                    onManage: onManageCards
                )
                .offset(y: CGFloat(index) * spacing)
                .offset(draggingAccount?.id == account.id ? dragOffset : .zero)
                .zIndex(draggingAccount?.id == account.id ? 99 : Double(index))
                .shadow(color: .black.opacity(0.12), radius: draggingAccount?.id == account.id ? 12 : 4, x: 0, y: 6)
                .gesture(dragGesture(for: account, at: index))
                .contextMenu {
                    Button("Add Pot") { onAddPot(account) }
                    Button("New Transaction") { onAddTransaction(account) }
                    Button("Manage Cards") { onManageCards() }
                    Divider()
                    Button(role: .destructive) { onDelete(account) } label: {
                        Text("Delete")
                        Image(systemName: "trash")
                    }
                }
            }
        }
        // Reserve vertical space for the stacked offsets so content below doesn't overlap
        .frame(height: 160 + CGFloat(max((selectedAccountId == nil ? accounts.count : 1) - 1, 0)) * spacing, alignment: .top)
        // Keep small top padding so the deck sits closer to the balance card
        .padding(.top, 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: draggingAccount?.id)
    }

    private func dragGesture(for account: Account, at index: Int) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard selectedAccountId == nil else { return }
                draggingAccount = account
                dragOffset = value.translation
            }
            .onEnded { value in
                guard selectedAccountId == nil else { return }
                let offset = Int(round(value.translation.height / spacing))
                let targetIndex = max(min(index + offset, accounts.count - 1), 0)
                if targetIndex != index {
                    onReorder(index, targetIndex)
                }
                draggingAccount = nil
                dragOffset = .zero
            }
    }
}

private struct AccountCardView: View {
    let account: Account
    var onTap: (() -> Void)? = nil
    var onManage: (() -> Void)? = nil

    private var gradient: LinearGradient {
        let start: Color
        let end: Color
        switch account.type {
        case "credit":
            start = Color.blue
            end = Color.indigo
        case "current":
            start = Color.red
            end = Color.orange
        case "savings":
            start = Color.green
            end = Color.mint
        default:
            start = Color.purple
            end = Color.indigo
        }
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Label {
                    Text(account.name)
                        .font(.system(size: 18, weight: .semibold))
                } icon: {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white.opacity(0.95))
                }
                .foregroundColor(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("£\(String(format: "%.2f", account.balance))")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Balance")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            HStack(alignment: .center) {
                Text(account.type.lowercased())
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                if let limit = account.credit_limit, account.type == "credit" {
                    Text("Limit £\(String(format: "%.0f", limit))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                }

                Button(action: { onManage?() }) {
                    Image(systemName: "ellipsis.vertical")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.15))
                        .clipShape(Capsule())
                        .accessibilityLabel("Manage")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 0)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
        .onTapGesture { onTap?() }
    }
}

// MARK: - Quick Actions

private struct QuickActionsView: View {
    let onManagePots: () -> Void
    let onSavings: () -> Void
    let onIncome: () -> Void
    let onReorder: () -> Void
    let onDiagnostics: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts")
                .font(.headline)
            HStack(spacing: 16) {
                QuickActionButton(icon: "tray.and.arrow.down", title: "Pots", action: onManagePots)
                QuickActionButton(icon: "banknote", title: "Savings", action: onSavings)
                QuickActionButton(icon: "calendar.badge.clock", title: "Incomes", action: onIncome)
            }
            HStack(spacing: 16) {
                QuickActionButton(icon: "rectangle.stack", title: "Reorder", action: onReorder)
                QuickActionButton(icon: "wrench.and.screwdriver", title: "Diagnostics", action: onDiagnostics)
                QuickActionButton(icon: "gearshape", title: "Settings", action: onSettings)
        }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.purple)
                    .clipShape(Circle())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity Feed

private struct ActivityFeedSection: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore
    @ObservedObject var activityStore: ActivityStore
    let activities: [ActivityItem]
    @Binding var selectedActivity: ActivityItem?
    let onViewAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity Feed")
                    .font(.headline)
                Spacer()
                Button("View All", action: onViewAll)
                    .font(.caption)
            }

            ActivityFilterChips(activityStore: activityStore)

            if activities.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "calendar",
                    description: Text("Transactions and scheduled payments will appear here once available.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(activities.prefix(6)) { activity in
                        ActivityRow(activity: activity, isMarked: activityStore.markedIdentifiers.contains(activity.id))
                            .onTapGesture {
                                if activityStore.isMarking {
                                    activityStore.toggleMark(for: activity)
                                } else {
                                    selectedActivity = activity
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await deleteActivity(activity) }
                                } label: { Label("Delete", systemImage: "trash") }

                                Button {
                                    selectedActivity = activity
                                } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                            }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func deleteActivity(_ activity: ActivityItem) async {
        guard let accountId = accountsStore.accounts.first(where: { $0.name == activity.accountName })?.id else { return }
        let parts = activity.id.split(separator: "-")
        let numericId = Int(parts.last ?? "")
        switch activity.category {
        case .income:
            if let id = numericId { await accountsStore.deleteIncome(accountId: accountId, incomeId: id) }
        case .expense:
            if let id = numericId { await accountsStore.deleteExpense(accountId: accountId, expenseId: id) }
        case .scheduledPayment:
            if let id = numericId, let context = scheduledPaymentsStore.items.first(where: { $0.accountId == accountId && $0.payment.id == id }) {
                await scheduledPaymentsStore.deletePayment(context: context)
            }
        case .transfer:
            if let transactionIdString = activity.metadata["transactionId"], let transactionId = Int(transactionIdString) {
                await accountsStore.deleteTransaction(id: transactionId)
            }
        }
    }
}

private struct ActivityFilterChips: View {
    @ObservedObject var activityStore: ActivityStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ActivityStore.Filter.allCases) { filter in
                    Button {
                        activityStore.filter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activityStore.filter == filter ? Color.purple.opacity(0.2) : Color.clear)
                            .foregroundColor(activityStore.filter == filter ? .purple : .primary)
                            .clipShape(Capsule())
                    }
                }
                if activityStore.isMarking {
                    Button("Mark All", action: activityStore.markAllFiltered)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                    Button("Clear", action: activityStore.clearMarks)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct ActivityRow: View {
    let activity: ActivityItem
    let isMarked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color(for: activity.category))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: icon(for: activity.category)).foregroundColor(.white))
                .overlay(
                    Group {
                        if isMarked {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .offset(x: 16, y: -16)
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detailLine(for: activity))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let vendor = vendorLine(for: activity) {
                    Text(vendor)
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedAmount)
                    .font(.subheadline)
                    .foregroundColor(activity.category == .income ? .green : .primary)
                Text(dayOfMonth(activity.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func color(for category: ActivityCategory) -> Color {
        switch category {
        case .income: return .green
        case .expense: return .red
        case .scheduledPayment: return .purple
        case .transfer: return .blue
        }
    }

    private func icon(for category: ActivityCategory) -> String {
        switch category {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .scheduledPayment: return "calendar"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    private func dayOfMonth(_ date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }

    private func detailLine(for activity: ActivityItem) -> String {
        switch activity.category {
        case .income:
            if let pot = activity.potName, !pot.isEmpty {
                return "\(activity.accountName) · \(pot)"
            }
            return activity.accountName
        case .expense:
            var parts: [String] = [activity.accountName]
            if let pot = activity.metadata["toPotName"], !pot.isEmpty {
                parts.append("· \(pot)")
            }
            if let destination = activity.metadata["toAccountName"], !destination.isEmpty {
                parts.append("→ \(destination)")
            }
            return parts.joined(separator: " ")
        case .scheduledPayment:
            if let pot = activity.potName, !pot.isEmpty {
                return "\(activity.accountName) · \(pot)"
            }
            return activity.accountName
        case .transfer:
            let direction = activity.metadata["direction"] ?? "out"
            let counterparty = activity.metadata["counterparty"] ?? ""
            let base: String
            if direction == "in" {
                if counterparty.isEmpty {
                    base = activity.accountName
                } else {
                    base = "\(counterparty) → \(activity.accountName)"
                }
            } else {
                if counterparty.isEmpty {
                    base = activity.accountName
                } else {
                    base = "\(activity.accountName) → \(counterparty)"
                }
            }
            let pot = activity.metadata["potName"].flatMap { $0.isEmpty ? nil : $0 } ?? activity.potName
            if let pot, !pot.isEmpty {
                return "\(base) · \(pot)"
            }
            return base
        }
    }

    private func vendorLine(for activity: ActivityItem) -> String? {
        guard let company = activity.company, !company.isEmpty else { return nil }
        if activity.category == .transfer {
            return "Vendor: \(company)"
        }
        return company
    }
}

// MARK: - Pots Panel

private struct PotEditContext: Identifiable, Hashable {
    let id = UUID()
    let account: Account
    let pot: Pot
}

private struct PotsPanelSection: View {
    let accounts: [Account]
    let potsByAccount: [Int: [Pot]]
    var onTapPot: (Account, Pot) -> Void = { _, _ in }
    var onDeletePot: (Account, Pot) -> Void = { _, _ in }

    private var allPots: [(account: Account, pot: Pot)] {
        var items: [(account: Account, pot: Pot)] = []
        for account in accounts {
            let sourcePots = (account.pots ?? potsByAccount[account.id] ?? [])
            for pot in sourcePots {
                items.append((account: account, pot: pot))
            }
        }
        // Sort by account then pot name
        return items.sorted { lhs, rhs in
            if lhs.account.name == rhs.account.name { return lhs.pot.name < rhs.pot.name }
            return lhs.account.name < rhs.account.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pots")
                    .font(.headline)
                Spacer()
            }

            if allPots.isEmpty {
                ContentUnavailableView(
                    "No Pots",
                    systemImage: "tray",
                    description: Text("Create pots to organize balances.")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(allPots.enumerated()), id: \.offset) { _, item in
                        PotRow(pot: item.pot, accountName: item.account.name)
                            .onTapGesture { onTapPot(item.account, item.pot) }
                            .contextMenu {
                                Button("Manage") { onTapPot(item.account, item.pot) }
                                Button(role: .destructive) { onDeletePot(item.account, item.pot) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { onDeletePot(item.account, item.pot) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { onTapPot(item.account, item.pot) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.blue)
                            }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Pot Editor

private struct PotEditorSheet: View {
    @EnvironmentObject private var potsStore: PotsStore
    @Environment(\.dismiss) private var dismiss

    let context: PotEditContext

    @State private var name: String = ""
    @State private var balance: String = ""
    @State private var excludeFromReset: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Pot") {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(context.account.name).foregroundStyle(.secondary)
                    }
                    TextField("Name", text: $name)
                    TextField("Balance", text: $balance).keyboardType(.decimalPad)
                    Toggle("Exclude from Reset", isOn: $excludeFromReset)
                        .onChange(of: excludeFromReset) { _, newValue in
                            Task { await potsStore.toggleExclusion(accountId: context.account.id, potName: context.pot.name) }
                        }
                }
            }
            .navigationTitle("Manage Pot")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                    Button(role: .destructive) { Task { await deletePot() } } label: { Text("Delete") }
                }
            }
            .onAppear { preload() }
        }
    }

    private var canSave: Bool { !name.isEmpty && Double(balance) != nil }

    private func preload() {
        name = context.pot.name
        balance = String(format: "%.2f", context.pot.balance)
        excludeFromReset = context.pot.excludeFromReset ?? false
    }

    private func save() async {
        guard let amount = Double(balance) else { return }
        let submission = PotSubmission(name: name, balance: amount, excludeFromReset: excludeFromReset)
        await potsStore.updatePot(accountId: context.account.id, existingPot: context.pot, submission: submission)
        dismiss()
    }

    private func deletePot() async {
        await potsStore.deletePot(accountId: context.account.id, potName: context.pot.name)
        dismiss()
    }
}

private struct PotRow: View {
    let pot: Pot
    let accountName: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "tray.fill").foregroundColor(.purple))

            VStack(alignment: .leading, spacing: 2) {
                Text(pot.name)
                    .font(.subheadline).fontWeight(.medium)
                Text(accountName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("£\(String(format: "%.2f", pot.balance))")
                    .font(.subheadline).foregroundColor(.primary)
                Text("Balance")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

private struct ActivityDetailPopover: View {
    let activity: ActivityItem

    var body: some View {
        ActivityEditorView(activity: activity)
    }
}

// MARK: - Activity Editor

struct ActivityEditorSheet: View {
    let activity: ActivityItem
    var body: some View {
        switch activity.category {
        case .transfer:
            TransactionActivityEditorView(activity: activity)
        default:
            ActivityEditorView(activity: activity)
        }
    }
}

private struct ActivityEditorView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore
    @Environment(\.dismiss) private var dismiss

    let activity: ActivityItem

    @State private var amount: String = ""
    @State private var descriptionText: String = ""
    @State private var company: String = ""
    @State private var dayOfMonth: String = ""
    @State private var selectedIncomePot: String? = nil
    @State private var selectedExpenseDestinationAccountId: Int?
    @State private var selectedExpenseDestinationPot: String? = nil

    private var isIncome: Bool { activity.category == .income }
    private var isExpense: Bool { activity.category == .expense }
    private var isScheduled: Bool { activity.category == .scheduledPayment }

    private var accountId: Int? {
        accountsStore.accounts.first(where: { $0.name == activity.accountName })?.id
    }

    private var destinationAccount: Account? {
        guard let selectedExpenseDestinationAccountId else { return nil }
        return accountsStore.account(for: selectedExpenseDestinationAccountId)
    }

    private var entityId: Int? {
        // Parse trailing numeric component from ActivityItem.id
        let parts = activity.id.split(separator: "-")
        if let last = parts.last, let value = Int(last) { return value }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(activity.accountName).foregroundStyle(.secondary)
                    }
                    if let pot = activity.potName {
                        HStack {
                            Text("Pot")
                            Spacer()
                            Text(pot).foregroundStyle(.secondary)
                        }
                    }
                }

                if isIncome || isExpense {
                    if isIncome {
                        Section("Destination") {
                            Picker("Pot", selection: $selectedIncomePot) {
                                Text("None").tag(nil as String?)
                                if let accountId, let account = accountsStore.account(for: accountId) {
                                    ForEach(account.pots ?? [], id: \.name) { pot in
                                        Text(pot.name).tag(pot.name as String?)
                                    }
                                }
                            }
                        }
                    }

                    if isExpense {
                        Section("Destination") {
                            Picker("Account", selection: $selectedExpenseDestinationAccountId) {
                                Text("None").tag(nil as Int?)
                                ForEach(accountsStore.accounts) { account in
                                    Text(account.name).tag(account.id as Int?)
                                }
                            }
                            if let pots = destinationAccount?.pots, !pots.isEmpty {
                                Picker("Pot", selection: $selectedExpenseDestinationPot) {
                                    Text("None").tag(nil as String?)
                                    ForEach(pots, id: \.name) { pot in
                                        Text(pot.name).tag(pot.name as String?)
                                    }
                                }
                            }
                        }
                    }

                    Section(isIncome ? "Edit Income" : "Edit Expense") {
                        TextField("Name", text: $descriptionText)
                        if isIncome { TextField("Company", text: $company) }
                        TextField("Amount", text: $amount).keyboardType(.decimalPad)
                        TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                    }
                } else {
                    Section("Scheduled Payment") {
                        Text(activity.title)
                        Text(activity.date, style: .date).foregroundStyle(.secondary)
                        if let company = activity.company { Text(company).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isIncome || isExpense {
                        Button("Save") { Task { await save() } }.disabled(!canSave)
                    }
                    Button(role: .destructive) { Task { await deleteItem() } } label: { Text("Delete") }
                }
            }
            .onAppear { preload() }
            .onChange(of: selectedExpenseDestinationAccountId) { _, _ in
                selectedExpenseDestinationPot = nil
            }
        }
    }

    private var canSave: Bool {
        Double(amount) != nil && !descriptionText.isEmpty && validDay && (isIncome ? !company.isEmpty : true)
    }

    private var validDay: Bool {
        if let d = Int(dayOfMonth), (1...31).contains(d) { return true }
        return false
    }

    private func preload() {
        descriptionText = activity.title
        company = activity.company ?? ""
        amount = String(format: "%.2f", abs(activity.amount))
        dayOfMonth = String(Calendar.current.component(.day, from: activity.date))
        if isIncome {
            let pot = activity.metadata["potName"].flatMap { $0.isEmpty ? nil : $0 } ?? activity.potName
            selectedIncomePot = pot
        }
        if isExpense {
            if let destinationId = activity.metadata["toAccountId"], let value = Int(destinationId) {
                selectedExpenseDestinationAccountId = value
            }
            selectedExpenseDestinationPot = activity.metadata["toPotName"].flatMap { $0.isEmpty ? nil : $0 } ?? activity.potName
        }
    }

    private func save() async {
        guard let accountId = accountId, let id = entityId, let money = Double(amount) else { return }
        if isIncome {
            let submission = IncomeSubmission(amount: money, description: descriptionText, company: company, date: dayOfMonth, potName: selectedIncomePot)
            await accountsStore.updateIncome(accountId: accountId, incomeId: id, submission: submission)
        } else if isExpense {
            let submission = ExpenseSubmission(amount: money, description: descriptionText, date: dayOfMonth, toAccountId: selectedExpenseDestinationAccountId, toPotName: selectedExpenseDestinationPot)
            await accountsStore.updateExpense(accountId: accountId, expenseId: id, submission: submission)
        }
        dismiss()
    }

    private func deleteItem() async {
        guard let accountId = accountId else { return }
        if isIncome, let id = entityId {
            await accountsStore.deleteIncome(accountId: accountId, incomeId: id)
            dismiss()
            return
        }
        if isExpense, let id = entityId {
            await accountsStore.deleteExpense(accountId: accountId, expenseId: id)
            dismiss()
            return
        }
        if isScheduled, let paymentId = entityId {
            // Find matching scheduled payment context
            if let context = scheduledPaymentsStore.items.first(where: { $0.accountId == accountId && $0.payment.id == paymentId }) {
                await scheduledPaymentsStore.deletePayment(context: context)
            }
            dismiss()
        }
    }
}

private struct TransactionActivityEditorView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let activity: ActivityItem

    @State private var fromAccountId: Int?
    @State private var toAccountId: Int?
    @State private var selectedPot: String?
    @State private var name: String = ""
    @State private var vendor: String = ""
    @State private var amount: String = ""
    @State private var dayOfMonth: String = ""

    private var transactionId: Int? {
        if let value = activity.metadata["transactionId"], let id = Int(value) { return id }
        return nil
    }

    private var toAccount: Account? {
        guard let toAccountId else { return nil }
        return accountsStore.account(for: toAccountId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From") {
                    Picker("Account", selection: $fromAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }

                Section("To") {
                    Picker("Account", selection: $toAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                    if let pots = toAccount?.pots, !pots.isEmpty {
                        Picker("Pot", selection: $selectedPot) {
                            Text("None").tag(nil as String?)
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name as String?)
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Vendor", text: $vendor)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                    Button(role: .destructive) { Task { await deleteItem() } } label: { Text("Delete") }
                }
            }
            .onAppear { preload() }
            .onChange(of: toAccountId) { _, _ in selectedPot = nil }
        }
    }

    private var canSave: Bool {
        guard let _ = fromAccountId, let _ = toAccountId, let money = Double(amount), money > 0 else { return false }
        guard !name.isEmpty, !vendor.isEmpty, let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    private func preload() {
        if let recordId = transactionId, let record = accountsStore.transaction(for: recordId) {
            fromAccountId = record.fromAccountId
            toAccountId = record.toAccountId
            selectedPot = record.toPotName
            name = record.name
            vendor = record.vendor
            amount = String(format: "%.2f", record.amount)
            if let day = Int(record.date) {
                dayOfMonth = String(day)
            } else {
                dayOfMonth = String(Calendar.current.component(.day, from: activity.date))
            }
        } else {
            fromAccountId = accountsStore.accounts.first(where: { $0.name == activity.accountName })?.id
            toAccountId = accountsStore.accounts.first(where: { $0.name == activity.metadata["counterparty"] })?.id
            selectedPot = activity.metadata["potName"].flatMap { $0.isEmpty ? nil : $0 }
            name = activity.title
            vendor = activity.company ?? ""
            amount = String(format: "%.2f", abs(activity.amount))
            dayOfMonth = String(Calendar.current.component(.day, from: activity.date))
        }
    }

    private func save() async {
        guard let recordId = transactionId,
              let fromAccountId,
              let toAccountId,
              let money = Double(amount)
        else { return }

        let submission = TransactionSubmission(
            name: name,
            vendor: vendor,
            amount: money,
            date: dayOfMonth,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            toPotName: selectedPot
        )
        await accountsStore.updateTransaction(id: recordId, submission: submission)
        dismiss()
    }

    private func deleteItem() async {
        guard let recordId = transactionId else { return }
        await accountsStore.deleteTransaction(id: recordId)
        dismiss()
    }
}

// MARK: - Dedicated Screens

struct PotsManagementView: View {
    @EnvironmentObject private var potsStore: PotsStore
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(accountsStore.accounts) { account in
                    Section(account.name) {
                        if let pots = potsStore.potsByAccount[account.id], !pots.isEmpty {
                            ForEach(pots, id: \.id) { pot in
                                VStack(alignment: .leading) {
                                    Text(pot.name)
                                    Text("£\(String(format: "%.2f", pot.balance))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("No pots")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Pots")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

struct SavingsInvestmentsView: View {
    @EnvironmentObject private var savingsStore: SavingsInvestmentsStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Total") {
                    Text("£\(String(format: "%.2f", savingsStore.totalBalance))")
                        .font(.title3)
                }
                ForEach(savingsStore.accounts) { account in
                    VStack(alignment: .leading) {
                        Text(account.name)
                        Text(account.type.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Savings & Investments")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { isPresented = false } }
            }
        }
    }
}

struct IncomeSchedulesBoardView: View {
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(incomeStore.schedules) { schedule in
                    VStack(alignment: .leading) {
                        Text(schedule.description)
                        Text("£\(String(format: "%.2f", schedule.amount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Income Schedules")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { isPresented = false } }
            }
        }
    }
}

struct CardReorderView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(accountsStore.accounts) { account in
                    Text(account.name)
                }
                .onMove { indices, newOffset in
                    Task { await accountsStore.reorderAccounts(fromOffsets: indices, toOffset: newOffset) }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Cards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
            }
        }
    }
}

struct DiagnosticsRunnerView: View {
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(diagnosticsStore.steps) { step in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(step.name)
                            Spacer()
                            switch step.status {
                            case .pending:
                                Image(systemName: "circle")
                            case .running:
                                ProgressView()
                            case .success(let message):
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                if let message {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            case .failure(let message):
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let duration = step.duration {
                            Text("Duration: \(String(format: "%.2f s", duration))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Run Again") {
                        Task { await diagnosticsStore.runFullSuite() }
                    }
                    .disabled(diagnosticsStore.isRunning)
                }
            }
            .task {
                await diagnosticsStore.runFullSuite()
            }
        }
    }
}
