import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var potsStore: PotsStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject private var incomeSchedulesStore: IncomeSchedulesStore
    @EnvironmentObject private var transferSchedulesStore: TransferSchedulesStore

    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var showingAddAccount = false
    @State private var showingAddPot = false
    @State private var showingAddIncome = false
    @State private var showingAddTransaction = false
    @State private var showingAddTarget = false
    // Removed income/expense/transaction add sheets
    @State private var showingPotsManager = false
    // Removed savings and income schedules
    // Reorder moved to Settings
    @State private var showingDiagnostics = false
    @State private var showingTransferSchedules = false
    @State private var showingIncomeSchedules = false
    @State private var showingSalarySorter = false
    @State private var showingResetConfirm = false
    @State private var isResettingBalances = false
    @State private var selectedAccountId: Int? = nil
    @State private var addIncomeTargetAccountId: Int? = nil
    @State private var addTransactionTargetAccountId: Int? = nil
    @State private var addTransactionTargetPotName: String? = nil
    @State private var addTargetAccountId: Int? = nil
    // Import/Export/Delete moved to Settings
    @State private var selectedPotContext: PotEditContext? = nil
    @State private var editingAccount: Account? = nil
    // Removed transaction destination context

    private let cardSpacing: CGFloat = 72

    private var filteredAccounts: [Account] { accountsStore.accounts }

    private var reorderableAccounts: [Account] {
        // Show all accounts including savings/investments in the card stack
        filteredAccounts
    }

    private var totalBalance: Double {
        accountsStore.accounts.reduce(0) { $0 + $1.balance }
    }

    private var todaysSpending: Double { 0 }

    // Activity feed removed

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
                            spacing: cardSpacing,
                            onReorder: handleReorder,
                            onAddPot: { _ in showingAddPot = true },
                            onEditAccount: { account in editingAccount = account },
                            onDelete: { account in
                                Task { await accountsStore.deleteAccount(id: account.id) }
                            }
                        )
                    }
                    ActivitiesPanelSection(
                        accounts: accountsStore.accounts,
                        transactions: accountsStore.transactions,
                        targets: accountsStore.targets,
                        selectedAccountId: selectedAccountId,
                        searchText: searchText
                    )

                    PotsPanelSection(
                        accounts: accountsStore.accounts,
                        potsByAccount: potsStore.potsByAccount,
                        selectedAccountId: selectedAccountId,
                        onTapPot: { account, pot in
                            selectedPotContext = PotEditContext(account: account, pot: pot)
                        },
                        onDeletePot: { account, pot in
                            Task { await potsStore.deletePot(accountId: account.id, potName: pot.name) }
                        }
                    )

                    QuickActionsView(
                        onManagePots: { showingPotsManager = true },
                        onTransferSchedules: { showingTransferSchedules = true },
                        onIncomeSchedules: { showingIncomeSchedules = true },
                        onSalarySorter: { showingSalarySorter = true },
                        onResetBalances: { showingResetConfirm = true },
                        onDiagnostics: { showingDiagnostics = true }
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
                    Menu {
                        Button("Add Account", action: { showingAddAccount = true })
                        Button("Add Pot", action: { showingAddPot = true })
                        Button("Add Transaction", action: {
                            addTransactionTargetAccountId = selectedAccountId
                            addTransactionTargetPotName = nil
                            showingAddTransaction = true
                        })
                        Button("Add Target", action: {
                            addTargetAccountId = selectedAccountId
                            showingAddTarget = true
                        })
                        Button("Add Income", action: {
                            addIncomeTargetAccountId = selectedAccountId
                            showingAddIncome = true
                        })
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
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
                AddIncomeSheet(presetAccountId: addIncomeTargetAccountId, isPresented: $showingAddIncome)
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionSheet(presetAccountId: addTransactionTargetAccountId, presetPotName: addTransactionTargetPotName, isPresented: $showingAddTransaction)
            }
            .sheet(isPresented: $showingAddTarget) {
                AddTargetSheet(presetAccountId: addTargetAccountId, isPresented: $showingAddTarget)
            }
            .sheet(item: $editingAccount) { account in
                EditAccountFormView(account: account)
            }
            .sheet(isPresented: $showingPotsManager) {
                PotsManagementView(isPresented: $showingPotsManager)
            }
            .sheet(isPresented: $showingTransferSchedules) {
                ManageTransferSchedulesView(isPresented: $showingTransferSchedules)
            }
            .sheet(isPresented: $showingIncomeSchedules) {
                ManageIncomeSchedulesView(isPresented: $showingIncomeSchedules)
            }
            .sheet(isPresented: $showingSalarySorter) {
                SalarySorterView(isPresented: $showingSalarySorter)
            }
            // Reorder moved to Settings
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticsRunnerView(isPresented: $showingDiagnostics)
            }
            .sheet(item: $selectedPotContext) { context in
                PotEditorSheet(context: context)
            }
            .alert("Reset Balances?", isPresented: $showingResetConfirm) {
                Button("Reset", role: .destructive) {
                    Task { await resetBalances() }
                }
                .disabled(isResettingBalances)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will set all non-excluded card and pot balances to 0 and re-enable all scheduled incomes for execution.")
            }
            // Activity editor removed
        }
    }

    private func refreshAllData() {
        Task { await accountsStore.loadAccounts() }
    }

    // Import/Export/Delete logic moved to Settings

    private func handleReorder(from sourceIndex: Int, to destinationIndex: Int) {
        let target = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        Task {
            await accountsStore.reorderAccounts(fromOffsets: IndexSet(integer: sourceIndex), toOffset: max(target, 0))
        }
    }

    @MainActor
    private func resetBalances() async {
        guard !isResettingBalances else { return }
        isResettingBalances = true
        defer { isResettingBalances = false }
        await accountsStore.resetBalances()
        await accountsStore.loadAccounts()
        await incomeSchedulesStore.load()
        await transferSchedulesStore.load()
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
    let spacing: CGFloat
    let onReorder: (Int, Int) -> Void
    let onAddPot: (Account) -> Void
    let onEditAccount: (Account) -> Void
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
                    onManage: nil
                )
                .offset(y: CGFloat(index) * spacing)
                .offset(draggingAccount?.id == account.id ? dragOffset : .zero)
                .zIndex(draggingAccount?.id == account.id ? 99 : Double(index))
                .shadow(color: .black.opacity(0.12), radius: draggingAccount?.id == account.id ? 12 : 4, x: 0, y: 6)
                .gesture(dragGesture(for: account, at: index))
                .contextMenu {
                    Button("Add Pot") { onAddPot(account) }
                    Button("Edit Account") { onEditAccount(account) }
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

// MARK: - Activities Panel (Combined)

struct ActivitiesPanelSection: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    enum Kind { case income, transaction, target }

    struct Item: Identifiable {
        let id = UUID()
        let kind: Kind
        let title: String
        let company: String?
        let amount: Double
        let dateString: String
        let accountName: String
        let potName: String?
        let metadata: [String:String]
        // Identity to support edit/delete actions
        let accountId: Int?
        let incomeId: Int?
        let transactionId: Int?
        let targetId: Int?
    }

    let accounts: [Account]
    let transactions: [TransactionRecord]
    let targets: [TargetRecord]
    let selectedAccountId: Int?
    // Optional limit override. If nil, uses settings value. If provided, uses this limit.
    var limit: Int? = nil
    // Optional pot filter (only applied on Activities screen usage)
    var selectedPotName: String? = nil
    var searchText: String = ""
    @AppStorage("activitiesMaxItems") private var maxItemsSetting: Int = 6

    @State private var filter: Filter = .all
    @AppStorage("activitiesSortOrder") private var sortOrderRaw: String = "day"

    // Edit sheet state
    @State private var editingIncome: (accountId: Int, incomeId: Int)? = nil
    @State private var editingTransactionId: Int? = nil
    @State private var editingTargetId: Int? = nil
    @State private var showEditIncome = false
    @State private var showEditTransaction = false
    @State private var showEditTarget = false

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case income = "Income"
        case transaction = "Transactions"
        case target = "Budget"
        var id: String { rawValue }
    }

    private var combinedItems: [Item] {
        var list: [Item] = []

        // Incomes from accounts
        let accountFilter: [Account] = {
            if let id = selectedAccountId, let a = accounts.first(where: { $0.id == id }) { return [a] }
            return accounts
        }()
        for account in accountFilter {
            for income in account.incomes ?? [] {
                list.append(Item(
                    kind: .income,
                    title: income.description,
                    company: income.company,
                    amount: income.amount,
                    dateString: income.date,
                    accountName: account.name,
                    potName: income.potName,
                    metadata: [:],
                    accountId: account.id,
                    incomeId: income.id,
                    transactionId: nil,
                    targetId: nil
                ))
            }
        }

        // Transactions from store
        let txFilter = transactions.filter { record in
            guard let sel = selectedAccountId else { return true }
            return record.toAccountId == sel || record.fromAccountId == sel
        }
        for r in txFilter {
            let acctName = accounts.first(where: { $0.id == r.toAccountId })?.name
                ?? (r.fromAccountId.flatMap { id in accounts.first(where: { $0.id == id })?.name } ?? "Unknown")
            let typeSuffix: String? = {
                guard let pt = r.paymentType else { return nil }
                return pt == "direct_debit" ? "Direct Debit" : "Card"
            }()
            list.append(Item(
                kind: .transaction,
                title: r.name,
                company: typeSuffix != nil ? "\(r.vendor) · \(typeSuffix!)" : r.vendor,
                amount: r.amount,
                dateString: r.date,
                accountName: acctName,
                potName: r.toPotName,
                metadata: [
                    "paymentType": r.paymentType ?? ""
                ],
                accountId: r.toAccountId,
                incomeId: nil,
                transactionId: r.id,
                targetId: nil
            ))
        }

        // Targets (account-only)
        let targetFilter = targets.filter { t in
            guard let sel = selectedAccountId else { return true }
            return t.accountId == sel
        }
        for t in targetFilter {
            let acctName = accounts.first(where: { $0.id == t.accountId })?.name ?? "Unknown"
            list.append(Item(
                kind: .target,
                title: t.name,
                company: nil,
                amount: t.amount,
                dateString: t.date,
                accountName: acctName,
                potName: nil,
                metadata: [:],
                accountId: t.accountId,
                incomeId: nil,
                transactionId: nil,
                targetId: t.id
            ))
        }

        // Apply type filter
        let filteredByType: [Item] = {
            switch filter {
            case .all: return list
            case .income: return list.filter { $0.kind == .income }
            case .transaction: return list.filter { $0.kind == .transaction }
            case .target: return list.filter { $0.kind == .target }
            }
        }()
        // Apply pot filter if provided
        let filtered: [Item] = {
            if let selectedPotName, !selectedPotName.isEmpty {
                return filteredByType.filter { $0.potName == selectedPotName }
            }
            return filteredByType
        }()
        let filteredBySearch: [Item] = {
            let term = normalizedSearch
            guard !term.isEmpty else { return filtered }
            return filtered.filter { matchesSearch($0, term: term) }
        }()

        // Apply sort from settings
        let sorted: [Item]
        switch sortOrderRaw.lowercased() {
        case "name":
            sorted = filteredBySearch.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "value":
            sorted = filteredBySearch.sorted {
                let lhs = abs($0.amount)
                let rhs = abs($1.amount)
                if lhs == rhs {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return lhs > rhs
            }
        case "type":
            sorted = filteredBySearch.sorted {
                // income, transaction, target; then by title
                func priority(_ k: Kind) -> Int { k == .income ? 0 : (k == .transaction ? 1 : 2) }
                let lp = priority($0.kind), rp = priority($1.kind)
                if lp == rp { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                return lp < rp
            }
        default: // "day"
            sorted = filteredBySearch.sorted {
                if let ld = Int($0.dateString), let rd = Int($1.dateString) { return ld > rd }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
        return sorted
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Activities")
                        .font(.headline)
                    Spacer()
                }
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }

            if !normalizedSearch.isEmpty {
                Text("Results for “\(normalizedSearch)”")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let itemsToShow: [Item] = {
                if !normalizedSearch.isEmpty { return combinedItems }
                if let limit { return Array(combinedItems.prefix(limit)) }
                if maxItemsSetting > 0 { return Array(combinedItems.prefix(maxItemsSetting)) }
                return combinedItems
            }()

            if itemsToShow.isEmpty {
                ContentUnavailableView(
                    !normalizedSearch.isEmpty ? "No Results" : (selectedAccountId != nil ? "No Activities for Card" : "No Activities"),
                    systemImage: "tray",
                    description: noResultsMessage
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(itemsToShow) { item in
                        ActivityListItemRow(item: item)
                            .contextMenu {
                                Button {
                                    handleEdit(item)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    handleDelete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { handleDelete(item) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { handleEdit(item) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.blue)
                            }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Edit sheets
        .sheet(isPresented: $showEditIncome) {
            if let ctx = editingIncome {
                EditIncomeSheet(accountId: ctx.accountId, incomeId: ctx.incomeId, isPresented: $showEditIncome)
            }
        }
        .sheet(isPresented: $showEditTransaction) {
            if let id = editingTransactionId {
                EditTransactionSheet(transactionId: id, isPresented: $showEditTransaction)
            }
        }
        .sheet(isPresented: $showEditTarget) {
            if let id = editingTargetId {
                EditTargetSheet(targetId: id, isPresented: $showEditTarget)
            }
        }
    }

    private func matchesSearch(_ item: Item, term: String) -> Bool {
        if item.title.localizedCaseInsensitiveContains(term) { return true }
        if let company = item.company, company.localizedCaseInsensitiveContains(term) { return true }
        if item.accountName.localizedCaseInsensitiveContains(term) { return true }
        if let pot = item.potName, pot.localizedCaseInsensitiveContains(term) { return true }
        let sanitizedTerm = term.replacingOccurrences(of: "£", with: "")
        let amountString = String(format: "%.2f", item.amount)
        if amountString.localizedCaseInsensitiveContains(sanitizedTerm) { return true }
        return false
    }

    private var noResultsMessage: Text {
        if !normalizedSearch.isEmpty {
            return Text("Try a different search term or clear the search to see recent activity.")
        }
        return Text("Add incomes or transactions to see them here.")
    }
}

private struct ActivityListItemRow: View {
    let item: ActivitiesPanelSection.Item

    private var formattedAmount: String { "£" + String(format: "%.2f", item.amount) }

    private var dayOfMonthText: String {
        func ordinal(_ d: Int) -> String {
            let teens = 11...13
            let suffix: String
            if teens.contains(d % 100) {
                suffix = "th"
            } else {
                switch d % 10 {
                case 1: suffix = "st"
                case 2: suffix = "nd"
                case 3: suffix = "rd"
                default: suffix = "th"
                }
            }
            return "\(d)\(suffix)"
        }
        if let d = Int(item.dateString), (1...31).contains(d) { return ordinal(d) }
        if let date = ISO8601DateFormatter().date(from: item.dateString) {
            let d = Calendar.current.component(.day, from: date)
            return ordinal(d)
        }
        return "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: icon).foregroundColor(.white))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(item.accountName)
                    if let pot = item.potName, !pot.isEmpty {
                        Text("·")
                        Text(pot)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let company = item.company, !company.isEmpty {
                    Text(company)
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.subheadline)
                    .foregroundColor(isIncome ? .green : .primary)
                Text(dayOfMonthText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private var isIncome: Bool { item.kind == .income }
    private var isTransaction: Bool { item.kind == .transaction }
    private var color: Color {
        switch item.kind {
        case .income:
            return .green.opacity(0.85)
        case .transaction:
            // Card vs Direct Debit coloring: purple for card, blue for DD
            if let t = item.metadata["paymentType"], t == "card" { return .purple.opacity(0.85) }
            if let t = item.metadata["paymentType"], t == "direct_debit" { return .blue.opacity(0.85) }
            return .blue.opacity(0.85)
        case .target:
            return .orange.opacity(0.85)
        }
    }
    private var icon: String {
        switch item.kind {
        case .income: return "arrow.down.circle.fill"
        case .transaction: return "arrow.left.arrow.right.circle.fill"
        case .target: return "target"
        }
    }
}

// MARK: - Edit Sheets for Activities

private struct EditIncomeSheet: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let accountId: Int
    let incomeId: Int
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var company: String = ""
    @State private var amount: String = ""
    @State private var paymentType: String = "direct_debit" // "card" or "direct_debit"
    @State private var dayOfMonth: String = ""
    @State private var selectedPot: String? = nil

    private var account: Account? { accountsStore.account(for: accountId) }
    private var income: Income? { account?.incomes?.first(where: { $0.id == incomeId }) }

    private var canSave: Bool {
        guard let money = Double(amount), money > 0 else { return false }
        guard !name.isEmpty, let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                if let account { HStack { Text("Account"); Spacer(); Text(account.name).foregroundStyle(.secondary) } }
                Section("Income") {
                    TextField("Name", text: $name)
                    TextField("Company", text: $company)
                    TextField("Value", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                    if let pots = account?.pots, !pots.isEmpty {
                        Picker("Pot", selection: $selectedPot) {
                            Text("None").tag(nil as String?)
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name as String?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Income")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button(role: .destructive) { Task { await deleteItem() } } label: {
                        Text("Delete Income")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding()
                }
                .background(.ultraThinMaterial)
            }
            .onAppear { preload() }
        }
    }

    private func preload() {
        if let income {
            name = income.description
            company = income.company
            amount = String(format: "%.2f", income.amount)
            dayOfMonth = income.date
            selectedPot = income.potName
        }
    }

    private func save() async {
        guard let money = Double(amount) else { return }
        let submission = IncomeSubmission(amount: abs(money), description: name, company: company, date: dayOfMonth, potName: selectedPot)
        await accountsStore.updateIncome(accountId: accountId, incomeId: incomeId, submission: submission)
        isPresented = false
    }

    private func deleteItem() async {
        await accountsStore.deleteIncome(accountId: accountId, incomeId: incomeId)
        isPresented = false
    }
}

private struct EditTransactionSheet: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let transactionId: Int
    @Binding var isPresented: Bool

    @State private var toAccountId: Int?
    @State private var selectedPot: String?
    @State private var name: String = ""
    @State private var vendor: String = ""
    @State private var amount: String = ""
    @State private var paymentType: String = "direct_debit" // "card" or "direct_debit"
    @State private var dayOfMonth: String = ""
    @State private var didLoad: Bool = false

    private var record: TransactionRecord? { accountsStore.transaction(for: transactionId) }
    private var toAccount: Account? { toAccountId.flatMap { accountsStore.account(for: $0) } }

    private var canSave: Bool {
        guard let _ = toAccountId, let money = Double(amount), money > 0 else { return false }
        guard !name.isEmpty, !vendor.isEmpty, let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    Picker("Payment Type", selection: $paymentType) {
                        Text("Card").tag("card")
                        Text("Direct Debit").tag("direct_debit")
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Name", text: $name)
                    TextField("Vendor", text: $vendor)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button(role: .destructive) { Task { await deleteItem() } } label: {
                        Text("Delete Transaction")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding()
                }
                .background(.ultraThinMaterial)
            }
            .onAppear { if !didLoad { preload(); didLoad = true } }
            .onChange(of: toAccountId) { _, _ in selectedPot = nil }
        }
    }

    private func preload() {
        if let record {
            toAccountId = record.toAccountId
            selectedPot = record.toPotName
            name = record.name
            vendor = record.vendor
            amount = String(format: "%.2f", record.amount)
            paymentType = record.paymentType ?? "direct_debit"
            paymentType = record.paymentType ?? "direct_debit"
            dayOfMonth = record.date
        }
    }

    private func save() async {
        guard let toAccountId, let money = Double(amount) else { return }
        let submission = TransactionSubmission(name: name, vendor: vendor, amount: money, date: dayOfMonth, fromAccountId: nil, toAccountId: toAccountId, toPotName: selectedPot, paymentType: paymentType)
        await accountsStore.updateTransaction(id: transactionId, submission: submission)
        isPresented = false
    }

    private func deleteItem() async {
        await accountsStore.deleteTransaction(id: transactionId)
        isPresented = false
    }
}

private struct EditTargetSheet: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let targetId: Int
    @Binding var isPresented: Bool

    @State private var accountName: String = ""
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var dayOfMonth: String = ""

    private var record: TargetRecord? { accountsStore.targets.first { $0.id == targetId } }

    private var canSave: Bool {
        guard !name.isEmpty, let money = Double(amount), money > 0 else { return false }
        guard let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                if !accountName.isEmpty {
                    HStack { Text("Account"); Spacer(); Text(accountName).foregroundStyle(.secondary) }
                }
                Section("Budget") {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button(role: .destructive) { Task { await deleteItem() } } label: {
                        Text("Delete Budget")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding()
                }
                .background(.ultraThinMaterial)
            }
            .onAppear { preload() }
        }
    }

    private func preload() {
        if let record {
            accountName = accountsStore.accounts.first(where: { $0.id == record.accountId })?.name ?? ""
            name = record.name
            amount = String(format: "%.2f", record.amount)
            dayOfMonth = record.date
        }
    }

    private func save() async {
        guard let record else { return }
        guard let money = Double(amount) else { return }
        let submission = TargetSubmission(name: name, amount: abs(money), date: dayOfMonth, accountId: record.accountId)
        await accountsStore.updateTarget(id: targetId, submission: submission)
        isPresented = false
    }

    private func deleteItem() async {
        await accountsStore.deleteTarget(id: targetId)
        isPresented = false
    }
}

// MARK: - Private helpers
private extension ActivitiesPanelSection {
    func handleEdit(_ item: Item) {
        switch item.kind {
        case .income:
            if let accountId = item.accountId, let incomeId = item.incomeId {
                editingIncome = (accountId, incomeId)
                showEditIncome = true
            }
        case .transaction:
            if let id = item.transactionId { editingTransactionId = id; showEditTransaction = true }
        case .target:
            if let id = item.targetId { editingTargetId = id; showEditTarget = true }
        }
    }

    func handleDelete(_ item: Item) {
        // Fire-and-forget deletes to keep UI simple
        Task {
            switch item.kind {
            case .income:
                if let accountId = item.accountId, let incomeId = item.incomeId {
                    await accountsStore.deleteIncome(accountId: accountId, incomeId: incomeId)
                }
            case .transaction:
                if let id = item.transactionId {
                    await accountsStore.deleteTransaction(id: id)
                }
            case .target:
                if let id = item.targetId {
                    await accountsStore.deleteTarget(id: id)
                }
            }
        }
    }
}

// (combined into ActivitiesPanelSection)

// MARK: - Add Transaction Sheet

private struct AddTransactionSheet: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let presetAccountId: Int?
    let presetPotName: String?
    @Binding var isPresented: Bool

    @State private var toAccountId: Int?
    @State private var potName: String? = nil
    @State private var paymentType: String = "direct_debit"
    @State private var type: String = ""
    @State private var company: String = ""
    @State private var amount: String = ""
    @State private var dayOfMonth: String = ""

    private var toAccount: Account? {
        guard let id = toAccountId else { return nil }
        return accountsStore.account(for: id)
    }

    private var canSave: Bool {
        guard let id = toAccountId, accountsStore.account(for: id) != nil else { return false }
        guard !type.isEmpty, !company.isEmpty, let money = Double(amount), money > 0 else { return false }
        guard let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("To") {
                    Picker("Account", selection: $toAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                    if let pots = toAccount?.pots, !pots.isEmpty {
                        Picker("Pot", selection: $potName) {
                            Text("None").tag(nil as String?)
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name as String?)
                            }
                        }
                    }
                }

                Section("Transaction") {
                    Picker("Payment Type", selection: $paymentType) {
                        Text("Card").tag("card")
                        Text("Direct Debit").tag("direct_debit")
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Name", text: $type)
                    TextField("Company", text: $company)
                    TextField("Value", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { Task { await save() } }.disabled(!canSave) }
            }
            .onAppear {
                toAccountId = presetAccountId ?? accountsStore.accounts.first?.id
                potName = presetPotName
            }
        }
    }

    private func save() async {
        guard let toAccountId, let money = Double(amount) else { return }
        let submission = TransactionSubmission(name: type, vendor: company, amount: abs(money), date: dayOfMonth, fromAccountId: nil, toAccountId: toAccountId, toPotName: potName, paymentType: paymentType)
        await accountsStore.addTransaction(submission)
        isPresented = false
    }
}

// MARK: - Add Target Sheet

private struct AddTargetSheet: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let presetAccountId: Int?
    @Binding var isPresented: Bool

    @State private var accountId: Int?
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var paymentType: String = "card"
    @State private var dayOfMonth: String = ""

    private var canSave: Bool {
        guard let id = accountId, accountsStore.account(for: id) != nil else { return false }
        guard !name.isEmpty, let money = Double(amount), money > 0 else { return false }
        guard let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: $accountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }

                Section("Target") {
                    TextField("Name", text: $name)
                    TextField("Value", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Target")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { Task { await save() } }.disabled(!canSave) }
            }
            .onAppear {
                accountId = presetAccountId ?? accountsStore.accounts.first?.id
            }
        }
    }

    private func save() async {
        guard let id = accountId, let money = Double(amount) else { return }
        let submission = TargetSubmission(name: name, amount: abs(money), date: dayOfMonth, accountId: id)
        await accountsStore.addTarget(submission)
        isPresented = false
    }
}

// (combined into ActivitiesPanelSection)

// MARK: - Add Income Sheet

private struct AddIncomeSheet: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let presetAccountId: Int?
    @Binding var isPresented: Bool

    @State private var selectedAccountId: Int?
    @State private var name: String = ""
    @State private var company: String = ""
    @State private var amount: String = ""
    @State private var dayOfMonth: String = ""

    private var canSave: Bool {
        guard let id = selectedAccountId else { return false }
        guard accountsStore.account(for: id) != nil else { return false }
        guard !name.isEmpty, !company.isEmpty, let money = Double(amount), money > 0 else { return false }
        guard let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let preset = presetAccountId, let account = accountsStore.account(for: preset) {
                        HStack {
                            Text("Selected")
                            Spacer()
                            Text(account.name).foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Account", selection: $selectedAccountId) {
                            Text("Select Account").tag(nil as Int?)
                            ForEach(accountsStore.accounts) { account in
                                Text(account.name).tag(account.id as Int?)
                            }
                        }
                    }
                }

                Section("Income") {
                    TextField("Name", text: $name)
                    TextField("Company", text: $company)
                    TextField("Value", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Income")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .onAppear {
                selectedAccountId = presetAccountId ?? accountsStore.accounts.first?.id
            }
        }
    }

    private func save() async {
        guard let id = presetAccountId ?? selectedAccountId, let money = Double(amount) else { return }
        let submission = IncomeSubmission(amount: abs(money), description: name, company: company, date: dayOfMonth, potName: nil)
        await accountsStore.addIncome(accountId: id, submission: submission)
        isPresented = false
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
    let onTransferSchedules: () -> Void
    let onIncomeSchedules: () -> Void
    let onSalarySorter: () -> Void
    let onResetBalances: () -> Void
    let onDiagnostics: () -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts")
                .font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                QuickActionButton(icon: "tray.and.arrow.down", title: "Manage Pots", tint: .indigo, action: onManagePots)
                QuickActionButton(icon: "arrow.left.arrow.right", title: "Transfer Schedules", tint: .blue, action: onTransferSchedules)
                QuickActionButton(icon: "calendar.badge.clock", title: "Income Schedules", tint: .green, action: onIncomeSchedules)
                QuickActionButton(icon: "chart.pie.fill", title: "Salary Sorter", tint: .purple, action: onSalarySorter)
                QuickActionButton(icon: "arrow.counterclockwise", title: "Reset Balances", tint: .red, action: onResetBalances)
                QuickActionButton(icon: "wrench.and.screwdriver", title: "Diagnostics", tint: .orange, action: onDiagnostics)
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
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(tint)
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

#if false
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
                    description: Text("Income, expenses, and transactions will appear here once available.")
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
        case .transaction:
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
        case .transaction: return .blue
    }
}

private func icon(for category: ActivityCategory) -> String {
    switch category {
    case .income: return "arrow.down.circle.fill"
    case .expense: return "arrow.up.circle.fill"
    case .scheduledPayment: return "calendar"
    case .transaction: return "arrow.left.arrow.right.circle.fill"
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
            if let destination = activity.metadata["toAccountName"], !destination.isEmpty {
                parts.append("to \(destination)")
            }
            return parts.joined(separator: " ")
        case .scheduledPayment:
            if let pot = activity.potName, !pot.isEmpty {
                return "\(activity.accountName) · \(pot)"
            }
            return activity.accountName
        case .transaction:
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
        if activity.category == .transaction {
            return "Vendor: \(company)"
        }
        return company
    }
}

#endif
// MARK: - Pots Panel

private struct PotEditContext: Identifiable, Hashable {
    let id = UUID()
    let account: Account
    let pot: Pot
}

private struct PotsPanelSection: View {
    let accounts: [Account]
    let potsByAccount: [Int: [Pot]]
    var selectedAccountId: Int? = nil
    var onTapPot: (Account, Pot) -> Void = { _, _ in }
    var onDeletePot: (Account, Pot) -> Void = { _, _ in }

    @State private var collapsedAccountIds: Set<Int> = []

    private var groupedPots: [(account: Account, pots: [Pot])] {
        let sourceAccounts: [Account] = {
            if let id = selectedAccountId,
               let acct = accounts.first(where: { $0.id == id }) {
                return [acct]
            }
            return accounts
        }()
        var collection: [(Account, [Pot])] = []
        for account in sourceAccounts.sorted(by: { $0.name < $1.name }) {
            let pots = (account.pots ?? potsByAccount[account.id] ?? []).sorted { $0.name < $1.name }
            if !pots.isEmpty {
                collection.append((account, pots))
            }
        }
        return collection
    }

    private func isCollapsed(_ accountId: Int) -> Bool {
        collapsedAccountIds.contains(accountId)
    }

    private func toggleAccount(_ accountId: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if collapsedAccountIds.contains(accountId) {
                collapsedAccountIds.remove(accountId)
            } else {
                collapsedAccountIds.insert(accountId)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pots")
                    .font(.headline)
                Spacer()
            }

            if groupedPots.isEmpty {
                ContentUnavailableView(
                    "No Pots",
                    systemImage: "tray",
                    description: Text("Create pots to organize balances.")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(groupedPots, id: \.account.id) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                toggleAccount(entry.account.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.account.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("\(entry.pots.count) pot\(entry.pots.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: isCollapsed(entry.account.id) ? "chevron.right" : "chevron.down")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)

                            if !isCollapsed(entry.account.id) {
                                VStack(spacing: 10) {
                                    ForEach(entry.pots, id: \.id) { pot in
                                        PotRow(pot: pot, accountName: entry.account.name)
                                            .onTapGesture { onTapPot(entry.account, pot) }
                                            .contextMenu {
                                                Button("Manage") { onTapPot(entry.account, pot) }
                                                Button(role: .destructive) { onDeletePot(entry.account, pot) } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) { onDeletePot(entry.account, pot) } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                Button { onTapPot(entry.account, pot) } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }.tint(.blue)
                                            }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
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
    @EnvironmentObject private var accountsStore: AccountsStore
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
                        .onChange(of: excludeFromReset) { _, _ in
                            let currentBalance = balance
                            Task {
                                await potsStore.toggleExclusion(accountId: context.account.id, potName: context.pot.name)
                                await MainActor.run {
                                    balance = currentBalance
                                }
                            }
                        }
                }
                Section("Transactions") {
                    let records = accountsStore.transactions.filter { $0.toAccountId == context.account.id && ($0.toPotName ?? "") == context.pot.name }
                    if records.isEmpty {
                        Text("No transactions for this pot").foregroundStyle(.secondary)
                    } else {
                        ForEach(records, id: \.id) { r in
                            HStack {
                                Text(r.name.isEmpty ? r.vendor : r.name)
                                Spacer()
                                Text("£\(String(format: "%.2f", r.amount))").foregroundStyle(.secondary)
                            }
                        }
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

#if false
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
        case .transaction:
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

    private var sourceAccountName: String? {
        guard let accountId, let account = accountsStore.account(for: accountId) else { return nil }
        return account.name
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isExpense {
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
                                Text("Select Account").tag(nil as Int?)
                                ForEach(accountsStore.accounts) { account in
                                    Text(account.name).tag(account.id as Int?)
                                }
                            }
                            if let sourceAccountName {
                                Text("Funds leave \(sourceAccountName)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
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
        }
    }

    private var canSave: Bool {
        let numericAmount = Double(amount) ?? 0
        let hasAmount = numericAmount > 0
        let hasDescription = !descriptionText.isEmpty
        let companyValid = isIncome ? !company.isEmpty : true
        let destinationValid = isExpense ? selectedExpenseDestinationAccountId != nil : true
        return hasAmount && hasDescription && validDay && companyValid && destinationValid
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
            if selectedExpenseDestinationAccountId == nil {
                selectedExpenseDestinationAccountId = accountId
            }
        }
    }

    private func save() async {
        guard let accountId = accountId, let id = entityId, let numericAmount = Double(amount) else { return }
        let money = abs(numericAmount)
        if isIncome {
            let submission = IncomeSubmission(amount: money, description: descriptionText, company: company, date: dayOfMonth, potName: selectedIncomePot)
            await accountsStore.updateIncome(accountId: accountId, incomeId: id, submission: submission)
        } else if isExpense {
            guard let selectedExpenseDestinationAccountId else { return }
            let submission = ExpenseSubmission(amount: money, description: descriptionText, date: dayOfMonth, toAccountId: selectedExpenseDestinationAccountId, toPotName: nil)
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

    @State private var toAccountId: Int?
    @State private var selectedPot: String?
    @State private var name: String = ""
    @State private var vendor: String = ""
    @State private var amount: String = ""
    @State private var dayOfMonth: String = ""
    @State private var didLoad: Bool = false

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
                    Picker("Payment Type", selection: $paymentType) {
                        Text("Card").tag("card")
                        Text("Direct Debit").tag("direct_debit")
                    }
                    .pickerStyle(.navigationLink)
                    // Show current selection as a subtle hint
                    Text(paymentType == "card" ? "Selected: Card" : "Selected: Direct Debit")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            .onAppear { if !didLoad { preload(); didLoad = true } }
            .onChange(of: toAccountId) { _, _ in selectedPot = nil }
        }
    }

    private var canSave: Bool {
        guard let _ = toAccountId, let money = Double(amount), money > 0 else { return false }
        guard !name.isEmpty, !vendor.isEmpty, let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    private func preload() {
        if let recordId = transactionId, let record = accountsStore.transaction(for: recordId) {
            toAccountId = record.toAccountId
            selectedPot = record.toPotName
            name = record.name
            vendor = record.vendor
            amount = String(format: "%.2f", record.amount)
            paymentType = record.paymentType ?? "card"
            if let day = Int(record.date) {
                dayOfMonth = String(day)
            } else {
                dayOfMonth = String(Calendar.current.component(.day, from: activity.date))
            }
        } else {
            toAccountId = accountsStore.accounts.first(where: { $0.name == activity.accountName })?.id
            selectedPot = activity.metadata["potName"].flatMap { $0.isEmpty ? nil : $0 }
            name = activity.title
            vendor = activity.company ?? ""
            if let company = activity.company, company == "Direct Debit" { paymentType = "direct_debit" } else { paymentType = "direct_debit" }
            amount = String(format: "%.2f", abs(activity.amount))
            dayOfMonth = String(Calendar.current.component(.day, from: activity.date))
        }
    }

    private func save() async {
        guard let recordId = transactionId,
              let toAccountId,
              let money = Double(amount)
        else { return }

        let submission = TransactionSubmission(
            name: name,
            vendor: vendor,
            amount: money,
            date: dayOfMonth,
            fromAccountId: nil,
            toAccountId: toAccountId,
            toPotName: selectedPot,
            paymentType: paymentType
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
#endif

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
