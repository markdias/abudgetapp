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
    @State private var showingBalanceHistory = false
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
            ZStack {
                BrandBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        if reorderableAccounts.isEmpty {
                            ContentUnavailableView(
                                "No Accounts",
                                systemImage: "creditcard",
                                description: Text("Use the add menu to create your first account.")
                            )
                            .brandCardStyle()
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
                            .brandCardStyle(padding: 0)
                        }

                        ActivitiesPanelSection(
                            accounts: accountsStore.accounts,
                            transactions: accountsStore.transactions,
                            targets: accountsStore.targets,
                            selectedAccountId: selectedAccountId,
                            searchText: searchText
                        )
                        .brandCardStyle()
                        .padding(.top, 16)

                        PotsPanelSection(
                            accounts: accountsStore.accounts,
                            potsByAccount: potsStore.potsByAccount,
                            selectedAccountId: selectedAccountId,
                            onTapPot: { account, pot in
                                selectedPotContext = PotEditContext(account: account, pot: pot)
                            },
                            onDeletePot: { account, pot in
                                Task { await potsStore.deletePot(accountId: account.id, potName: pot.name) }
                            },
                            onManagePots: { showingPotsManager = true }
                        )
                        .brandCardStyle()

                        QuickActionsView(
                            onTransferSchedules: { showingTransferSchedules = true },
                            onIncomeSchedules: { showingIncomeSchedules = true },
                            onSalarySorter: { showingSalarySorter = true },
                            onShowBalanceHistory: { showingBalanceHistory = true },
                            onResetBalances: { showingResetConfirm = true },
                            onDiagnostics: { showingDiagnostics = true }
                        )
                        .brandCardStyle()

                        BalanceSummaryCard(totalBalance: totalBalance, todaysSpending: todaysSpending)
                            .brandCardStyle()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
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
            .sheet(isPresented: $showingBalanceHistory) {
                BalanceReductionView(isPresented: $showingBalanceHistory)
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
        VStack(alignment: .leading, spacing: 22) {
            Text("Current Balance")
                .font(.system(.callout, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(LinearGradient(colors: [BrandTheme.accent.opacity(0.8), .white.opacity(0.8)], startPoint: .leading, endPoint: .trailing))

            Text("£\(String(format: "%.2f", totalBalance))")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [BrandTheme.accent, BrandTheme.accentSecondary], startPoint: .leading, endPoint: .trailing))
                .shadow(color: BrandTheme.accent.opacity(0.25), radius: 16, x: 0, y: 12)

            HStack(spacing: 16) {
                Label("Spent today", systemImage: "bolt.fill")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("£\(String(format: "%.2f", todaysSpending))")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(LinearGradient(colors: [BrandTheme.accentQuaternary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing))
            }

            Capsule()
                .fill(LinearGradient(colors: [BrandTheme.accent.opacity(0.4), BrandTheme.accentTertiary.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 6)
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 80, height: 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [BrandTheme.accent.opacity(0.22), BrandTheme.accentSecondary.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.8))
                )
                .overlay(
                    AngularGradient(colors: [BrandTheme.accent, BrandTheme.accentTertiary, BrandTheme.accentSecondary, BrandTheme.accent], center: .center)
                        .opacity(0.12)
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(BrandTheme.cardBorder, lineWidth: 1.4)
                        .opacity(0.75)
                )
        )
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

    private let previewDepth: Int = 4

    private var isStacked: Bool {
        selectedAccountId == nil && accounts.count > 1
    }

    private var stackSpacing: CGFloat {
        isStacked ? spacing * 0.45 : spacing
    }

    private var visibleAccountCount: Int {
        if let id = selectedAccountId,
           accounts.contains(where: { $0.id == id }) {
            return 1
        }
        return accounts.count
    }

    private var deckDepth: Int {
        min(visibleAccountCount, previewDepth)
    }

    private var stackHeight: CGFloat {
        AccountCardView.standardHeight
        + CGFloat(max(deckDepth - 1, 0)) * stackSpacing
        + (isStacked ? 36 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // When a card is selected, show only that card; otherwise show the whole stack
                let visibleAccounts: [Account] = {
                    if let id = selectedAccountId, let a = accounts.first(where: { $0.id == id }) {
                        return [a]
                    }
                    return accounts
                }()
                let cardSpacing = stackSpacing

                ForEach(Array(visibleAccounts.enumerated()), id: \.element.id) { index, account in
                    let depth = min(index, previewDepth - 1)
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
                    .offset(y: CGFloat(depth) * cardSpacing)
                    .offset(draggingAccount?.id == account.id ? dragOffset : .zero)
                    .zIndex(draggingAccount?.id == account.id ? 99 : Double(index))
                    .shadow(color: BrandTheme.accent.opacity(draggingAccount?.id == account.id ? 0.35 : 0.18), radius: draggingAccount?.id == account.id ? 16 : 10, x: 0, y: 12)
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
            .frame(
                height: stackHeight,
                alignment: .top
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
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
                let offset = Int(round(value.translation.height / stackSpacing))
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
    @State private var previewTransaction: TransactionRecord? = nil
    @State private var previewIncome: IncomePreviewContext? = nil
    @State private var previewTarget: TargetPreviewContext? = nil
    @State private var pendingDeleteItem: Item? = nil
    @State private var showDeleteConfirmation = false
    private let filterColumns: [GridItem] = [GridItem(.adaptive(minimum: 120), spacing: 10)]

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case income = "Income"
        case transaction = "Transactions"
        case target = "Budget"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "sparkles"
            case .income: return "arrow.down.circle"
            case .transaction: return "arrow.left.arrow.right.circle"
            case .target: return "scope"
            }
        }
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
                switch pt {
                case "direct_debit": return "Direct Debit"
                case "credit_card_charge": return "Credit Card Charge"
                case "card": return "Card"
                default: return pt.capitalized
                }
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent Activity")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(LinearGradient(colors: [BrandTheme.accent, BrandTheme.accentSecondary], startPoint: .leading, endPoint: .trailing))

                Text("Filter incomes, spending and goals in one feed.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: filterColumns, alignment: .leading, spacing: 10) {
                ForEach(Filter.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            filter = option
                        }
                    } label: {
                        Label {
                            Text(option.rawValue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        } icon: {
                            Image(systemName: option.icon)
                        }
                        .labelStyle(.titleAndIcon)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(filter == option ? BrandTheme.accent.opacity(0.18) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(filter == option ? BrandTheme.accent.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !normalizedSearch.isEmpty {
                Text("Results for “\(normalizedSearch)”")
                    .font(.system(.footnote, design: .rounded))
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
                VStack(spacing: 12) {
                    ForEach(itemsToShow) { item in
                        ActivityListItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { handleTap(item) }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .sheet(item: $previewTransaction) { record in
            TransactionPreviewSheet(record: record, accounts: accounts)
        }
        .sheet(item: $previewIncome) { context in
            IncomePreviewSheet(context: context)
        }
        .sheet(item: $previewTarget) { context in
            TargetPreviewSheet(context: context)
        }
        .confirmationDialog("Delete Activity?", isPresented: $showDeleteConfirmation, presenting: pendingDeleteItem) { item in
            Button("Delete", role: .destructive) {
                Task { await performDelete(item) }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: { item in
            Text("Are you sure you want to delete \"\(item.title)\"?")
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
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(item.accountName)
                    if let pot = item.potName, !pot.isEmpty {
                        Text("·")
                        Text(pot)
                    }
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

                if let company = item.company, !company.isEmpty {
                    Text(company)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(formattedAmount)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(amountGradient)
                Text(dayOfMonthText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .background(BlurView(style: .systemChromeMaterialDark).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var isIncome: Bool { item.kind == .income }
    private var isTransaction: Bool { item.kind == .transaction }
    private var icon: String {
        switch item.kind {
        case .income: return "arrow.down.circle.fill"
        case .transaction: return "arrow.left.arrow.right.circle.fill"
        case .target: return "scope"
        }
    }

    private var iconGradient: [Color] {
        switch item.kind {
        case .income:
            return [BrandTheme.accentTertiary, Color.green.opacity(0.7)]
        case .transaction:
            return [BrandTheme.accentSecondary, Color.blue.opacity(0.7)]
        case .target:
            return [BrandTheme.accentQuaternary, BrandTheme.accent]
        }
    }

    private var amountGradient: LinearGradient {
        if isIncome {
            return LinearGradient(colors: [BrandTheme.accentTertiary, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if isTransaction {
            return LinearGradient(colors: [BrandTheme.accentSecondary, Color.white.opacity(0.9)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [BrandTheme.accentQuaternary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing)
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
    @State private var dayOfMonth: String = ""
    @State private var selectedPot: String? = nil
    @State private var didPreload = false
    @State private var pendingSubmission: IncomeSubmission? = nil
    @State private var changeSummary: [ChangeSummaryField] = []
    @State private var previousSnapshot: [DetailSnapshot] = []
    @State private var updatedSnapshot: [DetailSnapshot] = []
    @State private var showSaveReview = false
    @State private var showDeleteConfirmation = false

    private var account: Account? { accountsStore.account(for: accountId) }
    private var income: Income? { account?.incomes?.first(where: { $0.id == incomeId }) }

    private var canSave: Bool {
        guard let money = Double(amount), money > 0 else { return false }
        guard !name.isEmpty, let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    if let account {
                        BrandFormSection("Account", padding: 18, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text((account.accountType ?? account.type).capitalized)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    BrandFormSection("Income") {
                        TextField("Name", text: $name)
                        TextField("Company", text: $company)
                        TextField("Value", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("Day of Month (1-31)", text: $dayOfMonth)
                            .keyboardType(.numberPad)
                        if let pots = account?.pots, !pots.isEmpty {
                            Picker("Pot", selection: $selectedPot) {
                                Text("None").tag(nil as String?)
                                ForEach(pots, id: \.name) { pot in
                                    Text(pot.name).tag(pot.name as String?)
                                }
                            }
                        }
                    }

                    BrandFormSection("Danger Zone", padding: 16, spacing: 12) {
                        Button(role: .destructive) { showDeleteConfirmation = true } label: {
                            Text("Delete Income")
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(Color.red.opacity(0.85))
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.red.opacity(0.45), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle("Edit Income")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { beginSaveReview() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showSaveReview) {
                if let submission = pendingSubmission {
                    ChangeReviewSheet(
                        title: "Review Income Changes",
                        changes: changeSummary,
                        previousSnapshot: previousSnapshot,
                        updatedSnapshot: updatedSnapshot,
                        onCancel: cancelSaveReview,
                        onConfirm: { confirmSaveReview(with: submission) }
                    )
                }
            }
            .onAppear { preloadIfNeeded() }
            .onChange(of: accountsStore.accounts) { _, _ in preloadIfNeeded() }
            .onChange(of: showSaveReview) { _, isPresented in
                if !isPresented {
                    resetReviewState()
                }
            }
            .confirmationDialog("Delete Income?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteItem() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this income?")
            }
        }
    }

    private func preloadIfNeeded() {
        guard !didPreload else { return }
        guard let income else { return }
        name = income.description
        company = income.company
        amount = String(format: "%.2f", income.amount)
        dayOfMonth = income.date
        selectedPot = income.potName
        didPreload = true
    }

    private func beginSaveReview() {
        guard let income, let submission = makeSubmission(basedOn: income) else { return }
        let accountName = account?.name ?? "Unknown"
        let previous = buildSnapshot(from: income, accountName: accountName)
        let updated = buildSnapshot(from: submission, accountName: accountName)
        changeSummary = computeChanges(previous: previous, updated: updated)
        previousSnapshot = previous
        updatedSnapshot = updated
        pendingSubmission = submission
        showSaveReview = true
    }

    private func cancelSaveReview() {
        resetReviewState()
        showSaveReview = false
    }

    private func confirmSaveReview(with submission: IncomeSubmission) {
        Task { await performSave(with: submission) }
    }

    private func performSave(with submission: IncomeSubmission) async {
        await accountsStore.updateIncome(accountId: accountId, incomeId: incomeId, submission: submission)
        await MainActor.run {
            showSaveReview = false
            resetReviewState()
            isPresented = false
        }
    }

    private func resetReviewState() {
        pendingSubmission = nil
        changeSummary = []
        previousSnapshot = []
        updatedSnapshot = []
    }

    private func makeSubmission(basedOn income: Income) -> IncomeSubmission? {
        guard let money = Double(amount) else { return nil }
        let trimmedDay = dayOfMonth.trimmingCharacters(in: .whitespacesAndNewlines)
        return IncomeSubmission(
            amount: abs(money),
            description: name,
            company: company,
            date: trimmedDay.isEmpty ? nil : trimmedDay,
            potName: selectedPot
        )
    }

    private func buildSnapshot(from income: Income, accountName: String) -> [DetailSnapshot] {
        [
            DetailSnapshot(label: "Name", value: income.description.isEmpty ? "—" : income.description),
            DetailSnapshot(label: "Company", value: income.company.isEmpty ? "—" : income.company),
            DetailSnapshot(label: "Amount", value: formattedAmount(income.amount)),
            DetailSnapshot(label: "Day", value: normalizeDay(income.date)),
            DetailSnapshot(label: "Pot", value: potDescription(income.potName)),
            DetailSnapshot(label: "Account", value: accountName)
        ]
    }

    private func buildSnapshot(from submission: IncomeSubmission, accountName: String) -> [DetailSnapshot] {
        let dayValue = submission.date ?? ""
        return [
            DetailSnapshot(label: "Name", value: submission.description.isEmpty ? "—" : submission.description),
            DetailSnapshot(label: "Company", value: submission.company.isEmpty ? "—" : submission.company),
            DetailSnapshot(label: "Amount", value: formattedAmount(submission.amount)),
            DetailSnapshot(label: "Day", value: normalizeDay(dayValue)),
            DetailSnapshot(label: "Pot", value: potDescription(submission.potName)),
            DetailSnapshot(label: "Account", value: accountName)
        ]
    }

    private func formattedAmount(_ value: Double) -> String {
        "£" + String(format: "%.2f", value)
    }

    private func potDescription(_ value: String?) -> String {
        guard let pot = value, !pot.isEmpty else { return "None" }
        return pot
    }

    private func normalizeDay(_ value: String) -> String {
        if let day = Int(value), (1...31).contains(day) { return "\(day)" }
        return value.isEmpty ? "—" : value
    }

    private func deleteItem() async {
        await accountsStore.deleteIncome(accountId: accountId, incomeId: incomeId)
        isPresented = false
    }
}

private struct ChangeSummaryField: Identifiable {
    let id = UUID()
    let label: String
    let previous: String
    let updated: String
}

private struct DetailSnapshot: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private func computeChanges(previous: [DetailSnapshot], updated: [DetailSnapshot]) -> [ChangeSummaryField] {
    let updatedLookup = Dictionary(uniqueKeysWithValues: updated.map { ($0.label, $0.value) })
    var changes: [ChangeSummaryField] = []
    for detail in previous {
        guard let newValue = updatedLookup[detail.label], detail.value != newValue else { continue }
        changes.append(ChangeSummaryField(label: detail.label, previous: detail.value, updated: newValue))
    }
    return changes
}

private struct EditTransactionSheet: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let transactionId: Int
    @Binding var isPresented: Bool

    @State private var toAccountId: Int?
    @State private var selectedPot: String?
    @State private var initialAccountId: Int?
    @State private var initialPotName: String?
    @State private var name: String = ""
    @State private var vendor: String = ""
    @State private var amount: String = ""
    @State private var paymentType: String = "direct_debit" // "card" or "direct_debit"
    @State private var dayOfMonth: String = ""
    @State private var linkedCreditAccountId: Int? = nil
    @State private var didPreload = false
    @State private var pendingSubmission: TransactionSubmission? = nil
    @State private var changeSummary: [ChangeSummaryField] = []
    @State private var previousSnapshot: [DetailSnapshot] = []
    @State private var updatedSnapshot: [DetailSnapshot] = []
    @State private var showSaveReview = false

    private var record: TransactionRecord? { accountsStore.transaction(for: transactionId) }
    private var toAccount: Account? { toAccountId.flatMap { accountsStore.account(for: $0) } }
    private var creditAccounts: [Account] {
        accountsStore.accounts.filter { $0.type == "credit" }
    }

    private var canSave: Bool {
        guard let _ = toAccountId, let money = Double(amount), money > 0 else { return false }
        guard !name.isEmpty, !vendor.isEmpty, let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("To") {
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

                    if !creditAccounts.isEmpty {
                        BrandFormSection("Credit Card Link") {
                            Picker("Linked Card", selection: $linkedCreditAccountId) {
                                Text("None").tag(nil as Int?)
                                ForEach(creditAccounts) { account in
                                    Text(account.name).tag(account.id as Int?)
                                }
                            }
                        }
                    }

                    BrandFormSection("Details") {
                        Picker("Payment Type", selection: $paymentType) {
                            Text("Card").tag("card")
                            Text("Direct Debit").tag("direct_debit")
                            Text("Credit Card Charge").tag("credit_card_charge").disabled(true)
                        }
                        .pickerStyle(.navigationLink)
                        TextField("Name", text: $name)
                        TextField("Vendor", text: $vendor)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("Day of Month (1-31)", text: $dayOfMonth)
                            .keyboardType(.numberPad)
                    }

                    BrandFormSection("Danger Zone", padding: 16, spacing: 12) {
                        Button(role: .destructive) { Task { await deleteItem() } } label: {
                            Text("Delete Transaction")
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(Color.red.opacity(0.85))
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.red.opacity(0.45), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { beginSaveReview() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showSaveReview) {
                if let submission = pendingSubmission {
                    ChangeReviewSheet(
                        title: "Review Transaction Changes",
                        changes: changeSummary,
                        previousSnapshot: previousSnapshot,
                        updatedSnapshot: updatedSnapshot,
                        onCancel: cancelSaveReview,
                        onConfirm: { confirmSaveReview(with: submission) }
                    )
                }
            }
            .onAppear { preloadIfNeeded() }
            .onChange(of: accountsStore.accounts) { _, _ in preloadIfNeeded() }
            .onChange(of: accountsStore.transactions) { _, _ in preloadIfNeeded() }
            .onChange(of: toAccountId) { _, newValue in handleAccountChange(newValue) }
            .onChange(of: showSaveReview) { _, isPresented in
                if !isPresented {
                    resetReviewState()
                }
            }
        }
    }

    private func preloadIfNeeded() {
        guard !didPreload else { return }
        guard let record else { return }
        initialAccountId = record.toAccountId
        initialPotName = record.toPotName
        toAccountId = record.toAccountId
        selectedPot = record.toPotName
        name = record.name
        vendor = record.vendor
        amount = String(format: "%.2f", record.amount)
        paymentType = record.paymentType ?? "direct_debit"
        dayOfMonth = record.date
        linkedCreditAccountId = record.linkedCreditAccountId
        didPreload = true
        sanitizeLinkedCreditCardSelection()
    }

    private func handleAccountChange(_ newValue: Int?) {
        guard let newValue, let account = accountsStore.account(for: newValue) else {
            selectedPot = nil
            return
        }

        guard let pots = account.pots, !pots.isEmpty else {
            selectedPot = nil
            return
        }

        if let selectedPot, pots.contains(where: { $0.name == selectedPot }) {
            return
        }

        if newValue == initialAccountId,
           let initialPotName,
           pots.contains(where: { $0.name == initialPotName }) {
            selectedPot = initialPotName
        } else {
            selectedPot = nil
        }
    }

    private func sanitizeLinkedCreditCardSelection() {
        guard let linkedId = linkedCreditAccountId else { return }
        if !creditAccounts.contains(where: { $0.id == linkedId }) {
            linkedCreditAccountId = nil
        }
    }

    private func beginSaveReview() {
        guard let currentRecord = record,
              let submission = makeSubmission(basedOn: currentRecord) else { return }
        let previous = buildSnapshot(from: currentRecord)
        let updated = buildSnapshot(from: submission)
        changeSummary = computeChanges(previous: previous, updated: updated)
        previousSnapshot = previous
        updatedSnapshot = updated
        pendingSubmission = submission
        showSaveReview = true
    }

    private func cancelSaveReview() {
        resetReviewState()
        showSaveReview = false
    }

    private func confirmSaveReview(with submission: TransactionSubmission) {
        Task {
            await performSave(with: submission)
        }
    }

    private func performSave(with submission: TransactionSubmission) async {
        await accountsStore.updateTransaction(id: transactionId, submission: submission)
        await MainActor.run {
            showSaveReview = false
            resetReviewState()
            isPresented = false
        }
    }

    private func resetReviewState() {
        pendingSubmission = nil
        changeSummary = []
        previousSnapshot = []
        updatedSnapshot = []
    }

    private func makeSubmission(basedOn record: TransactionRecord) -> TransactionSubmission? {
        guard let toAccountId, let money = Double(amount) else { return nil }
        let trimmedDay = dayOfMonth.trimmingCharacters(in: .whitespacesAndNewlines)
        return TransactionSubmission(
            name: name,
            vendor: vendor,
            amount: money,
            date: trimmedDay.isEmpty ? nil : trimmedDay,
            fromAccountId: record.fromAccountId,
            toAccountId: toAccountId,
            toPotName: selectedPot,
            paymentType: paymentType,
            linkedCreditAccountId: linkedCreditAccountId
        )
    }

    private func buildSnapshot(from record: TransactionRecord) -> [DetailSnapshot] {
        buildSnapshot(
            name: record.name,
            vendor: record.vendor,
            amount: record.amount,
            date: record.date,
            toAccountId: record.toAccountId,
            potName: record.toPotName,
            paymentType: record.paymentType,
            fromAccountId: record.fromAccountId,
            linkedCreditAccountId: record.linkedCreditAccountId
        )
    }

    private func buildSnapshot(from submission: TransactionSubmission) -> [DetailSnapshot] {
        let dayValue = submission.date ?? ""
        return buildSnapshot(
            name: submission.name,
            vendor: submission.vendor,
            amount: submission.amount,
            date: dayValue,
            toAccountId: submission.toAccountId,
            potName: submission.toPotName,
            paymentType: submission.paymentType,
            fromAccountId: submission.fromAccountId,
            linkedCreditAccountId: submission.linkedCreditAccountId
        )
    }

    private func buildSnapshot(
        name: String,
        vendor: String,
        amount: Double,
        date: String,
        toAccountId: Int,
        potName: String?,
        paymentType: String?,
        fromAccountId: Int?,
        linkedCreditAccountId: Int?
    ) -> [DetailSnapshot] {
        [
            DetailSnapshot(label: "Name", value: name.isEmpty ? "—" : name),
            DetailSnapshot(label: "Vendor", value: vendor.isEmpty ? "—" : vendor),
            DetailSnapshot(label: "Amount", value: formattedAmount(amount)),
            DetailSnapshot(label: "Day", value: date.isEmpty ? "—" : date),
            DetailSnapshot(label: "Payment Type", value: paymentTypeDescription(paymentType)),
            DetailSnapshot(label: "To Account", value: accountName(for: toAccountId)),
            DetailSnapshot(label: "Pot", value: potDescription(potName)),
            DetailSnapshot(label: "From Account", value: {
                guard let id = fromAccountId else { return "None" }
                return accountName(for: id)
            }()),
            DetailSnapshot(label: "Linked Credit Card", value: {
                guard let id = linkedCreditAccountId else { return "None" }
                return accountName(for: id)
            }())
        ]
    }

    private func formattedAmount(_ value: Double) -> String {
        "£" + String(format: "%.2f", value)
    }

    private func paymentTypeDescription(_ value: String?) -> String {
        switch value {
        case "card": return "Card"
        case "direct_debit": return "Direct Debit"
        case "credit_card_charge": return "Credit Card Charge"
        case .some(let value) where !value.isEmpty: return value.capitalized
        default: return "—"
        }
    }

    private func potDescription(_ value: String?) -> String {
        guard let pot = value, !pot.isEmpty else { return "None" }
        return pot
    }

    private func accountName(for id: Int) -> String {
        accountsStore.account(for: id)?.name ?? "Unknown"
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
    @State private var didPreload = false
    @State private var pendingSubmission: TargetSubmission? = nil
    @State private var changeSummary: [ChangeSummaryField] = []
    @State private var previousSnapshot: [DetailSnapshot] = []
    @State private var updatedSnapshot: [DetailSnapshot] = []
    @State private var showSaveReview = false
    @State private var showDeleteConfirmation = false

    private var record: TargetRecord? { accountsStore.targets.first { $0.id == targetId } }

    private var canSave: Bool {
        guard !name.isEmpty, let money = Double(amount), money > 0 else { return false }
        guard let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    if !accountName.isEmpty {
                        BrandFormSection("Account", padding: 18, spacing: 8) {
                            Text(accountName)
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }

                    BrandFormSection("Budget") {
                        TextField("Name", text: $name)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("Day of Month (1-31)", text: $dayOfMonth)
                            .keyboardType(.numberPad)
                    }

                    BrandFormSection("Danger Zone", padding: 16, spacing: 12) {
                        Button(role: .destructive) { showDeleteConfirmation = true } label: {
                            Text("Delete Budget")
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(Color.red.opacity(0.85))
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.red.opacity(0.45), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle("Edit Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { beginSaveReview() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showSaveReview) {
                if let submission = pendingSubmission {
                    ChangeReviewSheet(
                        title: "Review Budget Changes",
                        changes: changeSummary,
                        previousSnapshot: previousSnapshot,
                        updatedSnapshot: updatedSnapshot,
                        onCancel: cancelSaveReview,
                        onConfirm: { confirmSaveReview(with: submission) }
                    )
                }
            }
            .onAppear { preloadIfNeeded() }
            .onChange(of: accountsStore.targets) { _, _ in preloadIfNeeded() }
            .onChange(of: accountsStore.accounts) { _, _ in preloadIfNeeded() }
            .onChange(of: showSaveReview) { _, isPresented in
                if !isPresented {
                    resetReviewState()
                }
            }
            .confirmationDialog("Delete Budget?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteItem() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this budget?")
            }
        }
    }

    private func preloadIfNeeded() {
        guard !didPreload else { return }
        guard let record else { return }
        guard let account = accountsStore.accounts.first(where: { $0.id == record.accountId }) else { return }
        accountName = account.name
        name = record.name
        amount = String(format: "%.2f", record.amount)
        dayOfMonth = record.date
        didPreload = true
    }

    private func beginSaveReview() {
        guard let record, let submission = makeSubmission(basedOn: record) else { return }
        let previous = buildSnapshot(from: record, accountName: accountName)
        let updated = buildSnapshot(from: submission, accountName: accountName)
        changeSummary = computeChanges(previous: previous, updated: updated)
        previousSnapshot = previous
        updatedSnapshot = updated
        pendingSubmission = submission
        showSaveReview = true
    }

    private func cancelSaveReview() {
        resetReviewState()
        showSaveReview = false
    }

    private func confirmSaveReview(with submission: TargetSubmission) {
        Task { await performSave(with: submission) }
    }

    private func performSave(with submission: TargetSubmission) async {
        await accountsStore.updateTarget(id: targetId, submission: submission)
        await MainActor.run {
            showSaveReview = false
            resetReviewState()
            isPresented = false
        }
    }

    private func resetReviewState() {
        pendingSubmission = nil
        changeSummary = []
        previousSnapshot = []
        updatedSnapshot = []
    }

    private func makeSubmission(basedOn record: TargetRecord) -> TargetSubmission? {
        guard let money = Double(amount) else { return nil }
        let trimmedDay = dayOfMonth.trimmingCharacters(in: .whitespacesAndNewlines)
        return TargetSubmission(
            name: name,
            amount: abs(money),
            date: trimmedDay.isEmpty ? nil : trimmedDay,
            accountId: record.accountId
        )
    }

    private func buildSnapshot(from record: TargetRecord, accountName: String) -> [DetailSnapshot] {
        [
            DetailSnapshot(label: "Name", value: record.name.isEmpty ? "—" : record.name),
            DetailSnapshot(label: "Amount", value: formattedAmount(record.amount)),
            DetailSnapshot(label: "Day", value: normalizeDay(record.date)),
            DetailSnapshot(label: "Account", value: accountName)
        ]
    }

    private func buildSnapshot(from submission: TargetSubmission, accountName: String) -> [DetailSnapshot] {
        let dayValue = submission.date ?? ""
        return [
            DetailSnapshot(label: "Name", value: submission.name.isEmpty ? "—" : submission.name),
            DetailSnapshot(label: "Amount", value: formattedAmount(submission.amount)),
            DetailSnapshot(label: "Day", value: normalizeDay(dayValue)),
            DetailSnapshot(label: "Account", value: accountName)
        ]
    }

    private func formattedAmount(_ value: Double) -> String {
        "£" + String(format: "%.2f", value)
    }

    private func normalizeDay(_ value: String) -> String {
        if let day = Int(value), (1...31).contains(day) { return "\(day)" }
        return value.isEmpty ? "—" : value
    }

    private func deleteItem() async {
        await accountsStore.deleteTarget(id: targetId)
        isPresented = false
    }
}

// MARK: - Private helpers
private extension ActivitiesPanelSection {
    func handleTap(_ item: Item) {
        switch item.kind {
        case .transaction:
            guard let transactionId = item.transactionId else { return }
            if let record = transactions.first(where: { $0.id == transactionId }) {
                previewTransaction = record
            }
        case .income:
            guard
                let accountId = item.accountId,
                let incomeId = item.incomeId,
                let account = accountsStore.account(for: accountId),
                let income = account.incomes?.first(where: { $0.id == incomeId })
            else { return }
            previewIncome = IncomePreviewContext(income: income, accountName: account.name)
        case .target:
            guard
                let targetId = item.targetId,
                let target = targets.first(where: { $0.id == targetId })
            else { return }
            let accountName = accounts.first(where: { $0.id == target.accountId })?.name ?? item.accountName
            previewTarget = TargetPreviewContext(target: target, accountName: accountName)
        }
    }

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
        pendingDeleteItem = item
        showDeleteConfirmation = true
    }

    func performDelete(_ item: Item) async {
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
        await MainActor.run {
            showDeleteConfirmation = false
            pendingDeleteItem = nil
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
    @State private var linkedCreditAccountId: Int? = nil

    private var toAccount: Account? {
        guard let id = toAccountId else { return nil }
        return accountsStore.account(for: id)
    }

    private var creditAccounts: [Account] {
        accountsStore.accounts.filter { $0.type == "credit" }
    }

    private var canSave: Bool {
        guard let id = toAccountId, accountsStore.account(for: id) != nil else { return false }
        guard !type.isEmpty, !company.isEmpty, let money = Double(amount), money > 0 else { return false }
        guard let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("To") {
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

                    if !creditAccounts.isEmpty {
                        BrandFormSection("Credit Card Link") {
                            Picker("Linked Card", selection: $linkedCreditAccountId) {
                                Text("None").tag(nil as Int?)
                                ForEach(creditAccounts) { account in
                                    Text(account.name).tag(account.id as Int?)
                                }
                            }
                        }
                    }

                    BrandFormSection("Transaction") {
                        Picker("Payment Type", selection: $paymentType) {
                            Text("Card").tag("card")
                            Text("Direct Debit").tag("direct_debit")
                        }
                        .pickerStyle(.navigationLink)
                        TextField("Name", text: $type)
                        TextField("Company", text: $company)
                        TextField("Value", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("Day of Month (1-31)", text: $dayOfMonth)
                            .keyboardType(.numberPad)
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { Task { await save() } }.disabled(!canSave) }
            }
            .onAppear {
                toAccountId = presetAccountId ?? accountsStore.accounts.first?.id
                potName = presetPotName
                sanitizeLinkedCardSelection()
            }
            .onChange(of: accountsStore.accounts) { _, _ in sanitizeLinkedCardSelection() }
        }
    }

    private func save() async {
        guard let toAccountId, let money = Double(amount) else { return }
        let submission = TransactionSubmission(
            name: type,
            vendor: company,
            amount: abs(money),
            date: dayOfMonth,
            fromAccountId: nil,
            toAccountId: toAccountId,
            toPotName: potName,
            paymentType: paymentType,
            linkedCreditAccountId: linkedCreditAccountId
        )
        await accountsStore.addTransaction(submission)
        isPresented = false
    }

    private func sanitizeLinkedCardSelection() {
        guard let linkedId = linkedCreditAccountId else { return }
        if !creditAccounts.contains(where: { $0.id == linkedId }) {
            linkedCreditAccountId = nil
        }
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
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("Account") {
                        Picker("Account", selection: $accountId) {
                            Text("Select Account").tag(nil as Int?)
                            ForEach(accountsStore.accounts) { account in
                                Text(account.name).tag(account.id as Int?)
                            }
                        }
                    }

                    BrandFormSection("Target") {
                        TextField("Name", text: $name)
                        TextField("Value", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("Day of Month (1-31)", text: $dayOfMonth)
                            .keyboardType(.numberPad)
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
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
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("Account", spacing: 12) {
                        if let preset = presetAccountId, let account = accountsStore.account(for: preset) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Preset from quick action")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
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

                    BrandFormSection("Income") {
                        TextField("Name", text: $name)
                        TextField("Company", text: $company)
                        TextField("Value", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("Day of Month (1-31)", text: $dayOfMonth)
                            .keyboardType(.numberPad)
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
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
    static let cardHeight: CGFloat = 132

    let account: Account
    var onTap: (() -> Void)? = nil
    var onManage: (() -> Void)? = nil

    static var standardHeight: CGFloat { cardHeight }

    private var gradient: [Color] {
        switch account.type.lowercased() {
        case "credit":
            return [BrandTheme.accentSecondary, Color.blue.opacity(0.6), BrandTheme.accentTertiary]
        case "current":
            return [BrandTheme.accent, BrandTheme.accentQuaternary, Color.pink.opacity(0.7)]
        case "savings":
            return [BrandTheme.accentTertiary, Color.mint, Color.green.opacity(0.7)]
        default:
            return [BrandTheme.accentSecondary, BrandTheme.accent, BrandTheme.accentTertiary]
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1.1)
                )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.formattedBalance)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(account.accountType?.capitalized ?? account.type.capitalized)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(account.name)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)

                        if account.isCredit, let limit = account.credit_limit {
                            Text("Limit £\(String(format: "%.0f", limit))")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    if account.isCredit, let available = account.availableCredit {
                        Text("Available £\(String(format: "%.2f", available))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                    } else {
                        let potCount = account.pots?.count ?? 0
                        Text(potCount == 1 ? "1 pot · budgeted" : "\(potCount) pots")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    Spacer()

                    Image(systemName: account.isCredit ? "creditcard.fill" : "banknote.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, minHeight: AccountCardView.standardHeight, alignment: .leading)
        .onTapGesture { onTap?() }
    }
}

// MARK: - Quick Actions

private struct QuickActionsView: View {
    let onTransferSchedules: () -> Void
    let onIncomeSchedules: () -> Void
    let onSalarySorter: () -> Void
    let onShowBalanceHistory: () -> Void
    let onResetBalances: () -> Void
    let onDiagnostics: () -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Workflow Shortcuts")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(LinearGradient(colors: [BrandTheme.accent, BrandTheme.accentSecondary], startPoint: .leading, endPoint: .trailing))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                QuickActionButton(icon: "arrow.left.arrow.right", title: "Transfer\nSchedules", gradient: [BrandTheme.accentSecondary, Color.blue.opacity(0.7)], action: onTransferSchedules)
                QuickActionButton(icon: "calendar.badge.clock", title: "Income\nSchedules", gradient: [BrandTheme.accentTertiary, Color.green.opacity(0.7)], action: onIncomeSchedules)
                QuickActionButton(icon: "chart.pie.fill", title: "Salary\nSorter", gradient: [BrandTheme.accent, Color.pink.opacity(0.7)], action: onSalarySorter)
                QuickActionButton(icon: "chart.line.downtrend.xyaxis", title: "Balance\nReduction", gradient: [BrandTheme.accentTertiary, Color.teal.opacity(0.7)], action: onShowBalanceHistory)
                QuickActionButton(icon: "arrow.counterclockwise", title: "Reset\nBalances", gradient: [BrandTheme.accentQuaternary, BrandTheme.accent], action: onResetBalances)
                QuickActionButton(icon: "wrench.and.screwdriver", title: "Diagnostics", gradient: [BrandTheme.accentSecondary, Color.orange.opacity(0.8)], action: onDiagnostics)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: gradient.first?.opacity(0.45) ?? BrandTheme.accent.opacity(0.3), radius: 10, x: 0, y: 6)

                Text(title)
                    .multilineTextAlignment(.center)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .background(BlurView(style: .systemUltraThinMaterialDark).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
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
    var onManagePots: (() -> Void)? = nil

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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pots")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(LinearGradient(colors: [BrandTheme.accentSecondary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing))
                    Text("Segment balances and ring-fence your goals.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let onManagePots {
                    Button(action: onManagePots) {
                        Label("Manage", systemImage: "slider.horizontal.3")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(BrandTheme.accent.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }

            if groupedPots.isEmpty {
                ContentUnavailableView(
                    "No Pots",
                    systemImage: "tray",
                    description: Text("Create pots to organize balances.")
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(groupedPots, id: \.account.id) { entry in
                        VStack(alignment: .leading, spacing: 16) {
                            Button {
                                toggleAccount(entry.account.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.account.name)
                                            .font(.system(.headline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(entry.pots.count) pot\(entry.pots.count == 1 ? "" : "s")")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: isCollapsed(entry.account.id) ? "chevron.right" : "chevron.down")
                                        .font(.system(.footnote, design: .rounded).weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)

                            if !isCollapsed(entry.account.id) {
                                VStack(spacing: 12) {
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .background(BlurView(style: .systemMaterialDark).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
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
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("Pot") {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(context.account.name).foregroundStyle(.secondary)
                        }
                        TextField("Name", text: $name)
                        TextField("Balance", text: $balance)
                            .keyboardType(.decimalPad)
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

                    BrandFormSection("Transactions", spacing: 12) {
                        if potTransactions.isEmpty {
                            Text("No transactions for this pot")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(potTransactions, id: \.id) { r in
                                HStack {
                                    Text(r.name.isEmpty ? r.vendor : r.name)
                                    Spacer()
                                    Text("£\(String(format: "%.2f", r.amount))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
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

    private var potTransactions: [TransactionRecord] {
        accountsStore.transactions.filter { record in
            record.toAccountId == context.account.id && (record.toPotName ?? "") == context.pot.name
        }
    }

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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pot.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(accountName)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("£\(String(format: "%.2f", pot.balance))")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [BrandTheme.accentSecondary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing))
                Text("Balance")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .background(BlurView(style: .systemThinMaterialDark).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct IncomePreviewContext: Identifiable {
    let id = UUID()
    let income: Income
    let accountName: String
}

private struct TargetPreviewContext: Identifiable {
    let id = UUID()
    let target: TargetRecord
    let accountName: String
}

private struct TransactionPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let record: TransactionRecord
    let accounts: [Account]

    private var toAccountName: String {
        accounts.first(where: { $0.id == record.toAccountId })?.name ?? "Unknown"
    }

    private var fromAccountName: String? {
        guard let id = record.fromAccountId else { return nil }
        return accounts.first(where: { $0.id == id })?.name
    }

    private var formattedAmount: String { "£" + String(format: "%.2f", record.amount) }

    private var paymentTypeDescription: String {
        switch record.paymentType {
        case "card": return "Card"
        case "direct_debit": return "Direct Debit"
        case "credit_card_charge": return "Credit Card Charge"
        case .some(let value) where !value.isEmpty: return value.capitalized
        default: return "—"
        }
    }

    private var potDescription: String {
        if let pot = record.toPotName, !pot.isEmpty {
            return pot
        }
        return "None"
    }

    private var linkedCreditAccountName: String {
        guard let id = record.linkedCreditAccountId,
              let account = accounts.first(where: { $0.id == id }) else {
            return "None"
        }
        return account.name
    }

    private var dayDescription: String {
        if let day = Int(record.date), (1...31).contains(day) {
            return "\(day)"
        }
        return record.date.isEmpty ? "—" : record.date
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("Transaction", spacing: 12) {
                        LabeledContent("Name", value: record.name.isEmpty ? "—" : record.name)
                        LabeledContent("Vendor", value: record.vendor.isEmpty ? "—" : record.vendor)
                        LabeledContent("Amount", value: formattedAmount)
                        LabeledContent("Day", value: dayDescription)
                        LabeledContent("Payment Type", value: paymentTypeDescription)
                    }

                    BrandFormSection("Accounts", spacing: 12) {
                        LabeledContent("To Account", value: toAccountName)
                        if let fromAccountName, !fromAccountName.isEmpty {
                            LabeledContent("From Account", value: fromAccountName)
                        }
                        LabeledContent("Pot", value: potDescription)
                        LabeledContent("Linked Credit Card", value: linkedCreditAccountName)
                    }

                    BrandFormSection("Identifiers", spacing: 12) {
                        LabeledContent("Transaction ID", value: "\(record.id)")
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle("Transaction Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct IncomePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let context: IncomePreviewContext

    private var formattedAmount: String { "£" + String(format: "%.2f", context.income.amount) }
    private var potDescription: String {
        if let pot = context.income.potName, !pot.isEmpty { return pot }
        return "None"
    }
    private var dayDescription: String {
        let date = context.income.date
        if let day = Int(date), (1...31).contains(day) { return "\(day)" }
        return date.isEmpty ? "—" : date
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("Income", spacing: 12) {
                        LabeledContent("Name", value: context.income.description.isEmpty ? "—" : context.income.description)
                        LabeledContent("Company", value: context.income.company.isEmpty ? "—" : context.income.company)
                        LabeledContent("Amount", value: formattedAmount)
                        LabeledContent("Day", value: dayDescription)
                        LabeledContent("Pot", value: potDescription)
                    }

                    BrandFormSection("Account", spacing: 12) {
                        LabeledContent("Account", value: context.accountName)
                    }

                    BrandFormSection("Identifiers", spacing: 12) {
                        LabeledContent("Income ID", value: "\(context.income.id)")
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle("Income Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct TargetPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let context: TargetPreviewContext

    private var formattedAmount: String { "£" + String(format: "%.2f", context.target.amount) }
    private var dayDescription: String {
        let date = context.target.date
        if let day = Int(date), (1...31).contains(day) { return "\(day)" }
        return date.isEmpty ? "—" : date
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("Budget", spacing: 12) {
                        LabeledContent("Name", value: context.target.name.isEmpty ? "—" : context.target.name)
                        LabeledContent("Amount", value: formattedAmount)
                        LabeledContent("Day", value: dayDescription)
                    }

                    BrandFormSection("Account", spacing: 12) {
                        LabeledContent("Account", value: context.accountName)
                    }

                    BrandFormSection("Identifiers", spacing: 12) {
                        LabeledContent("Budget ID", value: "\(context.target.id)")
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle("Budget Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ChangeReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let changes: [ChangeSummaryField]
    let previousSnapshot: [DetailSnapshot]
    let updatedSnapshot: [DetailSnapshot]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                Form {
                    BrandFormSection("Changed Fields", spacing: 12) {
                        if changes.isEmpty {
                            Text("No changes detected. Saving will keep the item the same.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(changes) { change in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(change.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(change.previous) -> \(change.updated)")
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    BrandFormSection("Previous Version", spacing: 12) {
                        ForEach(previousSnapshot) { detail in
                            LabeledContent(detail.label, value: detail.value)
                        }
                    }

                    BrandFormSection("New Version", spacing: 12) {
                        ForEach(updatedSnapshot) { detail in
                            LabeledContent(detail.label, value: detail.value)
                        }
                    }
                }
                .brandFormStyle()
                .padding(.top, 12)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
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
    @State private var didPreload = false

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
            .onAppear { preloadIfNeeded() }
            .onChange(of: accountsStore.accounts) { _, _ in preloadIfNeeded() }
            .onChange(of: accountsStore.transactions) { _, _ in preloadIfNeeded() }
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

    private func preloadIfNeeded() {
        guard !didPreload else { return }
        if isExpense && accountId == nil {
            return
        }
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
        didPreload = true
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
    @State private var paymentType: String = "card"
    @State private var linkedCreditAccountId: Int? = nil
    @State private var didLoad: Bool = false
    @State private var didPreload = false

    private var transactionId: Int? {
        if let value = activity.metadata["transactionId"], let id = Int(value) { return id }
        return nil
    }

    private var toAccount: Account? {
        guard let toAccountId else { return nil }
        return accountsStore.account(for: toAccountId)
    }

    private var creditAccounts: [Account] {
        accountsStore.accounts.filter { $0.type == "credit" }
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

                if !creditAccounts.isEmpty {
                    Section("Credit Card Link") {
                        Picker("Linked Card", selection: $linkedCreditAccountId) {
                            Text("None").tag(nil as Int?)
                            ForEach(creditAccounts) { account in
                                Text(account.name).tag(account.id as Int?)
                            }
                        }
                    }
                }

                Section("Details") {
                    Picker("Payment Type", selection: $paymentType) {
                        Text("Card").tag("card")
                        Text("Direct Debit").tag("direct_debit")
                        Text("Credit Card Charge").tag("credit_card_charge").disabled(true)
                    }
                    .pickerStyle(.navigationLink)
                    // Show current selection as a subtle hint
                    Text({
                        switch paymentType {
                        case "card": return "Selected: Card"
                        case "direct_debit": return "Selected: Direct Debit"
                        case "credit_card_charge": return "Selected: Credit Card Charge"
                        default: return "Selected: \(paymentType.capitalized)"
                        }
                    }())
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
            .onAppear {
                preloadIfNeeded()
                sanitizeLinkedCardSelection()
            }
            .onChange(of: accountsStore.accounts) { _, _ in
                preloadIfNeeded()
                sanitizeLinkedCardSelection()
            }
            .onChange(of: accountsStore.transactions) { _, _ in preloadIfNeeded() }
            .onChange(of: toAccountId) { _, _ in selectedPot = nil }
        }
    }

    private var canSave: Bool {
        guard let _ = toAccountId, let money = Double(amount), money > 0 else { return false }
        guard !name.isEmpty, !vendor.isEmpty, let day = Int(dayOfMonth), (1...31).contains(day) else { return false }
        return true
    }

    private func preloadIfNeeded() {
        guard !didPreload else { return }
        if let recordId = transactionId, let record = accountsStore.transaction(for: recordId) {
            toAccountId = record.toAccountId
            selectedPot = record.toPotName
            name = record.name
            vendor = record.vendor
            amount = String(format: "%.2f", record.amount)
            paymentType = record.paymentType ?? "card"
            linkedCreditAccountId = record.linkedCreditAccountId
            if let day = Int(record.date) {
                dayOfMonth = String(day)
            } else {
                dayOfMonth = String(Calendar.current.component(.day, from: activity.date))
            }
            didPreload = true
            return
        } else {
            guard let fallbackAccountId = accountsStore.accounts.first(where: { $0.name == activity.accountName })?.id else {
                return
            }
            toAccountId = fallbackAccountId
            selectedPot = activity.metadata["potName"].flatMap { $0.isEmpty ? nil : $0 }
            name = activity.title
            vendor = activity.company ?? ""
            if let company = activity.company, company == "Direct Debit" { paymentType = "direct_debit" } else { paymentType = "card" }
            amount = String(format: "%.2f", abs(activity.amount))
            dayOfMonth = String(Calendar.current.component(.day, from: activity.date))
            linkedCreditAccountId = activity.metadata["linkedCreditAccountId"].flatMap { Int($0) }
            didPreload = true
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
            paymentType: paymentType,
            linkedCreditAccountId: linkedCreditAccountId
        )
        await accountsStore.updateTransaction(id: recordId, submission: submission)
        dismiss()
    }

    private func deleteItem() async {
        guard let recordId = transactionId else { return }
        await accountsStore.deleteTransaction(id: recordId)
        dismiss()
    }

    private func sanitizeLinkedCardSelection() {
        guard let linkedId = linkedCreditAccountId else { return }
        if !creditAccounts.contains(where: { $0.id == linkedId }) {
            linkedCreditAccountId = nil
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
