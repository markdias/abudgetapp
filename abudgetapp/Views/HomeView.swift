import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var potsStore: PotsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
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
    @State private var showingTransferComposer = false
    @State private var showingPotsManager = false
    @State private var showingSavings = false
    @State private var showingTransferBoard = false
    @State private var showingIncomeSchedules = false
    @State private var showingSalarySorter = false
    @State private var showingCardReorder = false
    @State private var showingDiagnostics = false
    @State private var selectedActivity: ActivityItem?
    @State private var selectedAccountId: Int? = nil
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = JSONDocument()
    @State private var showingDeleteAllConfirm = false
    @State private var selectedPotContext: PotEditContext? = nil

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
                            onAddTransaction: { _ in showingAddExpense = true },
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
                        onTransfers: { showingTransferBoard = true },
                        onIncome: { showingIncomeSchedules = true },
                        onSalarySorter: { showingSalarySorter = true },
                        onReorder: { showingCardReorder = true }
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

                    Button(action: { showingTransferComposer = true }) {
                        Image(systemName: "arrowtriangle.right.fill")
                    }
                    .help("New transfer schedule")

                    Menu {
                        Button("Add Account", action: { showingAddAccount = true })
                        Button("Add Pot", action: { showingAddPot = true })
                        Button("Add Income", action: { showingAddIncome = true })
                        Button("Add Expense", action: { showingAddExpense = true })
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
                            _ = try await APIService.shared.importBudgetState(from: data)
                            await refreshAllAfterImport()
                        } catch {
                            print("Import failed: \(error)")
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
            .sheet(isPresented: $showingTransferComposer) {
                TransferComposerView(isPresented: $showingTransferComposer)
            }
            .sheet(isPresented: $showingPotsManager) {
                PotsManagementView(isPresented: $showingPotsManager)
            }
            .sheet(isPresented: $showingSavings) {
                SavingsInvestmentsView(isPresented: $showingSavings)
            }
            .sheet(isPresented: $showingTransferBoard) {
                TransferBoardView(isPresented: $showingTransferBoard)
            }
            .sheet(isPresented: $showingIncomeSchedules) {
                IncomeSchedulesBoardView(isPresented: $showingIncomeSchedules)
            }
            .sheet(isPresented: $showingSalarySorter) {
                SalarySorterView(isPresented: $showingSalarySorter)
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
            await transferStore.load()
            await incomeStore.load()
        }
    }

    private func refreshAllAfterImport() async {
        await accountsStore.loadAccounts()
        await transferStore.load()
        await incomeStore.load()
        await savingsStore.load()
    }

    private func exportAllData() async {
        do {
            let data = try await APIService.shared.exportBudgetState()
            exportDocument = JSONDocument(data: data)
            showingExporter = true
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func deleteAllData() async {
        do {
            _ = try await APIService.shared.clearAllData()
            await refreshAllAfterImport()
        } catch {
            print("Delete all failed: \(error)")
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
    let onTransfers: () -> Void
    let onIncome: () -> Void
    let onSalarySorter: () -> Void
    let onReorder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts")
                .font(.headline)
            HStack(spacing: 16) {
                QuickActionButton(icon: "tray.and.arrow.down", title: "Pots", action: onManagePots)
                QuickActionButton(icon: "banknote", title: "Savings", action: onSavings)
                QuickActionButton(icon: "arrow.left.arrow.right", title: "Transfers", action: onTransfers)
            }
            HStack(spacing: 16) {
                QuickActionButton(icon: "calendar.badge.clock", title: "Incomes", action: onIncome)
                QuickActionButton(icon: "chart.pie", title: "Salary", action: onSalarySorter)
                QuickActionButton(icon: "rectangle.stack", title: "Reorder", action: onReorder)
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
                Text("\(activity.accountName)\(activity.potName != nil ? " · \(activity.potName!)" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        }
    }

    private func icon(for category: ActivityCategory) -> String {
        switch category {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .scheduledPayment: return "calendar"
        }
    }

    private func dayOfMonth(_ date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
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

private struct ActivityEditorSheet: View {
    let activity: ActivityItem
    var body: some View { ActivityEditorView(activity: activity) }
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

    private var isIncome: Bool { activity.category == .income }
    private var isExpense: Bool { activity.category == .expense }
    private var isScheduled: Bool { activity.category == .scheduledPayment }

    private var accountId: Int? {
        accountsStore.accounts.first(where: { $0.name == activity.accountName })?.id
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
                    Section(isIncome ? "Edit Income" : "Edit Expense") {
                        TextField("Description", text: $descriptionText)
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
    }

    private func save() async {
        guard let accountId = accountId, let id = entityId, let money = Double(amount) else { return }
        if isIncome {
            let submission = IncomeSubmission(amount: money, description: descriptionText, company: company, date: dayOfMonth)
            await accountsStore.updateIncome(accountId: accountId, incomeId: id, submission: submission)
        } else if isExpense {
            let submission = ExpenseSubmission(amount: money, description: descriptionText, date: dayOfMonth)
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

struct TransferBoardView: View {
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(transferStore.groupsByDestination()) { group in
                    Section(group.title) {
                        if let subtitle = group.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(group.schedules) { schedule in
                            VStack(alignment: .leading) {
                                Text(schedule.description)
                                Text("£\(String(format: "%.2f", schedule.amount))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transfer Schedules")
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

struct SalarySorterView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @Binding var isPresented: Bool

    private struct TransferPreview: Identifiable {
        let id: Int
        let schedule: TransferSchedule
        let amount: Double
        let destinationStartingBalance: Double
        let destinationFinalBalance: Double
        let destinationLabel: String
        let destinationIsPot: Bool
        let sourceLabel: String?
        let sourceStartingBalance: Double?
        let sourceFinalBalance: Double?
        let items: [TransferItem]
    }

    private struct AccountPreview: Identifiable {
        let account: Account
        let transfers: [TransferPreview]
        let totalAmount: Double
        let startingBalance: Double
        let balanceAfterIncome: Double
        let balanceAfterTransfers: Double

        var id: Int { account.id }
    }

    private struct PreviewContext {
        let accounts: [AccountPreview]
        let salaryOutflowTotal: Double
    }

    private struct PotKey: Hashable {
        let accountId: Int
        let name: String
    }

    private var activeIncomes: [IncomeSchedule] {
        incomeStore.schedules.filter { $0.isActive && !$0.isCompleted }
    }

    private var incomeTotal: Double {
        activeIncomes.reduce(0) { $0 + $1.amount }
    }

    private var activeTransfers: [TransferSchedule] {
        transferStore.schedules.filter { $0.isActive && !$0.isCompleted }
    }

    private var incomesByAccount: [Int: Double] {
        var dict: [Int: Double] = [:]
        for income in activeIncomes {
            dict[income.accountId, default: 0] += income.amount
        }
        return dict
    }

    private var previewContext: PreviewContext {
        guard !accountsStore.accounts.isEmpty else { return PreviewContext(accounts: [], salaryOutflowTotal: 0) }

        let accounts = accountsStore.accounts
        let accountStartingBalances = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.balance) })

        var accountAfterIncome = accountStartingBalances
        for (accountId, amount) in incomesByAccount {
            accountAfterIncome[accountId, default: accountStartingBalances[accountId] ?? 0] += amount
        }

        var accountBalances = accountAfterIncome

        var potStartingBalances: [PotKey: Double] = [:]
        var potBalances: [PotKey: Double] = [:]
        var potLookupById: [Int: PotKey] = [:]
        var potLookupByName: [String: [PotKey]] = [:]

        for account in accounts {
            for pot in account.pots ?? [] {
                let key = PotKey(accountId: account.id, name: pot.name)
                potStartingBalances[key] = pot.balance
                potBalances[key] = pot.balance
                potLookupById[pot.id] = key
                potLookupByName[pot.name, default: []].append(key)
            }
        }

        let resolvePotKey: (String, Int?, Int) -> PotKey? = { identifier, accountHint, destinationAccountId in
            if let numericId = Int(identifier), let key = potLookupById[numericId] {
                return key
            }
            if let accountId = accountHint {
                let key = PotKey(accountId: accountId, name: identifier)
                if potStartingBalances[key] != nil {
                    return key
                }
            }
            let destinationKey = PotKey(accountId: destinationAccountId, name: identifier)
            if potStartingBalances[destinationKey] != nil {
                return destinationKey
            }
            if let matches = potLookupByName[identifier] {
                if matches.count == 1 {
                    return matches[0]
                }
                if let accountId = accountHint, let match = matches.first(where: { $0.accountId == accountId }) {
                    return match
                }
                if let match = matches.first(where: { $0.accountId == destinationAccountId }) {
                    return match
                }
                return matches.first
            }
            return nil
        }

        var previewsByAccount: [Int: [TransferPreview]] = [:]
        var totalsByAccount: [Int: Double] = [:]
        var salaryOutflowsByAccount: [Int: Double] = [:]

        for schedule in activeTransfers.sorted(by: { $0.id < $1.id }) {
            let amount = schedule.amount

            var sourceLabel: String?
            var sourceStarting: Double?
            var sourceFinal: Double?
            var sourceAccountId: Int?

            if let fromPotId = schedule.fromPotId, !fromPotId.isEmpty,
               let key = resolvePotKey(fromPotId, schedule.fromAccountId, schedule.toAccountId) {
                let starting = potBalances[key] ?? potStartingBalances[key] ?? 0
                sourceStarting = starting
                let newValue = starting - amount
                potBalances[key] = newValue
                sourceFinal = newValue
                sourceAccountId = key.accountId
                let accountName = accountsStore.account(for: key.accountId)?.name ?? "Account #\(key.accountId)"
                sourceLabel = "\(accountName) · Pot: \(key.name)"
            } else if let fromAccountId = schedule.fromAccountId {
                let starting = accountBalances[fromAccountId]
                    ?? accountAfterIncome[fromAccountId]
                    ?? accountStartingBalances[fromAccountId]
                    ?? 0
                sourceStarting = starting
                let newValue = starting - amount
                accountBalances[fromAccountId] = newValue
                sourceFinal = newValue
                sourceAccountId = fromAccountId
                let accountName = accountsStore.account(for: fromAccountId)?.name ?? "Account #\(fromAccountId)"
                sourceLabel = accountName
            } else if let fromPotId = schedule.fromPotId, !fromPotId.isEmpty {
                sourceLabel = "Pot: \(fromPotId)"
            }

            if let accountId = sourceAccountId {
                salaryOutflowsByAccount[accountId, default: 0] += amount
            }

            let destinationAccountId = schedule.toAccountId
            let destinationLabel: String
            let destinationStarting: Double
            let destinationFinal: Double
            var isPotDestination = false

            if let potName = schedule.toPotName, !potName.isEmpty {
                isPotDestination = true
                let key = PotKey(accountId: destinationAccountId, name: potName)
                let starting = potBalances[key] ?? potStartingBalances[key] ?? 0
                destinationStarting = starting
                let newValue = starting + amount
                potBalances[key] = newValue
                destinationFinal = newValue
                let accountName = accountsStore.account(for: destinationAccountId)?.name ?? "Account #\(destinationAccountId)"
                destinationLabel = "\(accountName) · Pot: \(potName)"
            } else {
                let starting = accountBalances[destinationAccountId]
                    ?? accountAfterIncome[destinationAccountId]
                    ?? accountStartingBalances[destinationAccountId]
                    ?? 0
                destinationStarting = starting
                let newValue = starting + amount
                accountBalances[destinationAccountId] = newValue
                destinationFinal = newValue
                destinationLabel = accountsStore.account(for: destinationAccountId)?.name ?? "Account #\(destinationAccountId)"
            }

            let preview = TransferPreview(
                id: schedule.id,
                schedule: schedule,
                amount: amount,
                destinationStartingBalance: destinationStarting,
                destinationFinalBalance: destinationFinal,
                destinationLabel: destinationLabel,
                destinationIsPot: isPotDestination,
                sourceLabel: sourceLabel,
                sourceStartingBalance: sourceStarting,
                sourceFinalBalance: sourceFinal,
                items: schedule.items ?? []
            )
            previewsByAccount[destinationAccountId, default: []].append(preview)
            totalsByAccount[destinationAccountId, default: 0] += amount
        }

        let previews = previewsByAccount.compactMap { accountId, transfers in
            guard let account = accountsStore.account(for: accountId) else { return nil }
            let starting = accountStartingBalances[accountId] ?? 0
            let afterIncome = accountAfterIncome[accountId] ?? starting
            let afterTransfers = accountBalances[accountId] ?? afterIncome
            return AccountPreview(
                account: account,
                transfers: transfers,
                totalAmount: totalsByAccount[accountId] ?? 0,
                startingBalance: starting,
                balanceAfterIncome: afterIncome,
                balanceAfterTransfers: afterTransfers
            )
        }
        .sorted { $0.account.name < $1.account.name }
        let incomeAccounts = Set(activeIncomes.map { $0.accountId })
        let salaryOutflow = incomeAccounts.reduce(0) { partial, accountId in
            partial + (salaryOutflowsByAccount[accountId] ?? 0)
        }

        return PreviewContext(accounts: previews, salaryOutflowTotal: salaryOutflow)
    }

    var body: some View {
        let context = previewContext
        let previews = context.accounts
        let remainingBalance = incomeTotal - context.salaryOutflowTotal

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Income")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(incomeSubtitle())
                                    .font(.callout.weight(.semibold))
                            }
                            Spacer()
                            Text(formatGBP(incomeTotal))
                                .font(.title3.bold())
                        }
                        if activeIncomes.isEmpty {
                            Text("Activate an income schedule to preview its salary split.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Scheduled Transfers")
                            .font(.headline)

                        if previews.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nothing to move just yet.")
                                    .font(.subheadline.weight(.semibold))
                                Text("Add or activate transfer schedules to see their projected balances.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            ForEach(previews) { preview in
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preview.account.name)
                                                .font(.headline)
                                            Text("After incomes \(formatGBP(preview.balanceAfterIncome))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(formatGBP(preview.balanceAfterTransfers))
                                                .font(.title3.bold())
                                            Text("Post transfers")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    VStack(spacing: 10) {
                                        ForEach(preview.transfers) { transfer in
                                            VStack(alignment: .leading, spacing: 12) {
                                                HStack(alignment: .firstTextBaseline) {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(transfer.schedule.description)
                                                            .font(.subheadline.weight(.semibold))
                                                        if let source = transfer.sourceLabel {
                                                            Text("From \(source)")
                                                                .font(.caption2)
                                                                .foregroundStyle(.secondary)
                                                        }
                                                        Text("To \(transfer.destinationLabel)")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    Spacer()
                                                    Text(formatGBP(transfer.amount))
                                                        .font(.subheadline.weight(.semibold))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(chipColor(forPot: transfer.destinationIsPot))
                                                        .clipShape(Capsule())
                                                }

                                                if !transfer.items.isEmpty {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text("Breakdown")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                        ForEach(transfer.items, id: \.self) { item in
                                                            HStack {
                                                                Text(item.description)
                                                                Spacer()
                                                                Text(formatGBP(item.amount))
                                                                    .foregroundStyle(.secondary)
                                                            }
                                                            .font(.caption)
                                                        }
                                                    }
                                                }

                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Text("Current balance")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                        Spacer()
                                                        Text(formatGBP(transfer.destinationStartingBalance))
                                                            .font(.caption.weight(.semibold))
                                                    }
                                                    HStack {
                                                        Text("After transfer")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                        Spacer()
                                                        Text(formatGBP(transfer.destinationFinalBalance))
                                                            .font(.body.weight(.semibold))
                                                            .foregroundColor(transfer.destinationFinalBalance >= 0 ? .primary : .red)
                                                    }
                                                    if let source = transfer.sourceLabel, let sourceAfter = transfer.sourceFinalBalance {
                                                        Text("Source after: \(source) → \(formatGBP(sourceAfter))")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                    }

                                    Divider()

                                    HStack {
                                        Text("Scheduled total")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(formatGBP(preview.totalAmount))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }

                    if incomeTotal > 0 || context.salaryOutflowTotal > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatGBP(remainingBalance))
                                .font(.title3.bold())
                            Text(remainingBalance >= 0 ? "Available after scheduled moves" : "Shortfall after scheduled moves")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(remainingBalance >= 0 ? Color.blue.opacity(0.12) : Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Salary Sorter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
            .task {
                if accountsStore.accounts.isEmpty {
                    await accountsStore.loadAccounts()
                }
                await incomeStore.load()
                await transferStore.load()
            }
        }
    }

    private func chipColor(forPot: Bool) -> Color {
        forPot ? Color.purple.opacity(0.18) : Color.blue.opacity(0.18)
    }

    private func formatGBP(_ value: Double) -> String {
        let formatted = String(format: "%.2f", abs(value))
        let currency = "£" + formatted
        return value < 0 ? "-\(currency)" : currency
    }

    private func incomeSubtitle() -> String {
        if activeIncomes.isEmpty { return "No active schedules" }
        let companies = Set(activeIncomes.map { $0.company })
        if companies.count == 1, let company = companies.first { return company }
        return "\(activeIncomes.count) schedules"
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
