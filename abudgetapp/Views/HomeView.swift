import SwiftUI

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

    private let cardSpacing: CGFloat = 22

    private var filteredAccounts: [Account] {
        guard !searchText.isEmpty else { return accountsStore.accounts }
        return accountsStore.accounts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var reorderableAccounts: [Account] {
        filteredAccounts.filter { $0.type != "savings" && $0.type != "investment" }
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
        if searchText.isEmpty {
            return activityStore.filteredActivities
        }
        return activityStore.filteredActivities.filter { activity in
            activity.title.localizedCaseInsensitiveContains(searchText) ||
            activity.accountName.localizedCaseInsensitiveContains(searchText) ||
            (activity.potName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    BalanceSummaryCard(totalBalance: totalBalance, todaysSpending: todaysSpending)

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
                            searchText: searchText,
                            spacing: cardSpacing,
                            onReorder: handleReorder,
                            onAddPot: { account in
                                showingAddPot = true
                            },
                            onAddTransaction: { account in
                                showingAddExpense = true
                            },
                            onShowDetails: { account in
                                showingCardReorder = true
                            },
                            onDelete: { account in
                                Task { await accountsStore.deleteAccount(id: account.id) }
                            }
                        )
                    }

                    QuickActionsView(
                        onManagePots: { showingPotsManager = true },
                        onSavings: { showingSavings = true },
                        onTransfers: { showingTransferBoard = true },
                        onIncome: { showingIncomeSchedules = true },
                        onSalarySorter: { showingSalarySorter = true },
                        onReorder: { showingCardReorder = true }
                    )

                    ActivityFeedSection(
                        activityStore: activityStore,
                        activities: filteredActivities,
                        selectedActivity: $selectedActivity,
                        onViewAll: { selectedTab = 1 }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
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
                        Button("Run Diagnostics", action: { showingDiagnostics = true })
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
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
            .popover(item: $selectedActivity) { activity in
                ActivityDetailPopover(activity: activity)
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
    let searchText: String
    let spacing: CGFloat
    let onReorder: (Int, Int) -> Void
    let onAddPot: (Account) -> Void
    let onAddTransaction: (Account) -> Void
    let onShowDetails: (Account) -> Void
    let onDelete: (Account) -> Void

    @State private var draggingAccount: Account?
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                AccountCardView(account: account)
                    .offset(y: CGFloat(index) * spacing)
                    .offset(draggingAccount?.id == account.id ? dragOffset : .zero)
                    .zIndex(draggingAccount?.id == account.id ? 99 : Double(index))
                    .shadow(color: .black.opacity(0.12), radius: draggingAccount?.id == account.id ? 12 : 4, x: 0, y: 6)
                    .gesture(dragGesture(for: account, at: index))
                    .contextMenu {
                        Button("Add Pot") { onAddPot(account) }
                        Button("New Transaction") { onAddTransaction(account) }
                        Button("Reorder Cards") { onShowDetails(account) }
                        Divider()
                        Button(role: .destructive) { onDelete(account) } label: {
                            Text("Delete")
                            Image(systemName: "trash")
                        }
                    }
            }
        }
        .padding(.top, spacing)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: draggingAccount?.id)
    }

    private func dragGesture(for account: Account, at index: Int) -> some Gesture {
        DragGesture()
            .onChanged { value in
                draggingAccount = account
                dragOffset = value.translation
            }
            .onEnded { value in
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

    private var gradient: LinearGradient {
        let start: Color
        let end: Color
        switch account.type {
        case "current":
            start = Color.blue
            end = Color.blue.opacity(0.7)
        case "credit":
            start = Color.orange
            end = Color.red.opacity(0.8)
        case "savings":
            start = Color.green
            end = Color.green.opacity(0.6)
        default:
            start = Color.purple
            end = Color.purple.opacity(0.6)
        }
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(account.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("£\(String(format: "%.2f", account.balance))")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(account.accountType ?? "Personal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            HStack {
                if let limit = account.credit_limit, account.type == "credit" {
                    Label("Limit £\(String(format: "%.0f", limit))", systemImage: "creditcard")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                Text(activity.date, style: .date)
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
}

private struct ActivityDetailPopover: View {
    let activity: ActivityItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(activity.title)
                .font(.headline)
            Text(activity.formattedAmount)
                .font(.title3)
                .bold()
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label(activity.accountName, systemImage: "creditcard")
                if let pot = activity.potName {
                    Label(pot, systemImage: "tray")
                }
                if let company = activity.company, !company.isEmpty {
                    Label(company, systemImage: "building.2")
                }
                Label {
                    Text(activity.date, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
            }
            if !activity.metadata.isEmpty {
                Divider()
                ForEach(activity.metadata.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(activity.metadata[key] ?? "")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
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
    @EnvironmentObject private var activityStore: ActivityStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Salary Sorter")
                    .font(.title3.bold())
                Text("Breakdown of incoming salary allocations across pots and accounts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List {
                    ForEach(activityStore.activities.filter { $0.category == .income }) { income in
                        VStack(alignment: .leading) {
                            Text(income.title)
                            Text(income.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Salary Sorter")
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
