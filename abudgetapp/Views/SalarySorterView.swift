import SwiftUI

struct SalarySorterView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    // Show incomes even if executed (include all active incomes)
    private var pendingIncomes: [IncomeSchedule] {
        incomeStore.schedules.filter { $0.isActive }
    }
    private var incomeTotal: Double { pendingIncomes.reduce(0) { $0 + $1.amount } }

    // Collapsible state and grouped accounts
    @State private var expandedBudgetAccounts: Set<Int> = []
    @State private var expandedMainAccounts: Set<Int> = []
    @State private var expandedPotKeys: Set<String> = [] // key: "acct-<id>-pot-<name>"

    // Toast notification for copy feedback
    @State private var showToast = false
    @State private var toastMessage = ""

    private var destinationAccounts: [Account] {
        accountsStore.accounts.filter { account in
            let hasBudgets = accountsStore.targets.contains { $0.accountId == account.id }
            let hasTx = accountsStore.transactions.contains { $0.kind == .scheduled && $0.toAccountId == account.id }
            return hasBudgets || hasTx
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var transfersTotal: Double {
        destinationAccounts.reduce(0) { acc, account in
            acc + accountPreviewTotal(account)
        }
    }
    private var remaining: Double { incomeTotal - transfersTotal }
    private var hasCompletedTransfers: Bool {
        transferStore.schedules.contains { $0.isActive && $0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        incomeHeader

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Scheduled Transfers")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                Spacer()
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [ModernTheme.secondaryAccent.opacity(0.45), ModernTheme.primaryAccent.opacity(0.55)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 80, height: 4)
                                    .opacity(0.7)
                            }

                            if destinationAccounts.isEmpty {
                                ContentUnavailableView(
                                    "No pending transfer schedules",
                                    systemImage: "tray",
                                    description: Text("Create transfer schedules to see their allocations here.")
                                )
                                .glassCard()
                            } else {
                                VStack(spacing: 18) {
                                    ForEach(destinationAccounts, id: \.id) { account in
                                        destinationGroup(for: account)
                                    }
                                }
                            }
                        }

                        remainingFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 620)
                }

                // Toast notification
                VStack {
                    if showToast {
                        Text(toastMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [ModernTheme.primaryAccent, ModernTheme.secondaryAccent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 8)
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showToast)
            }
            .navigationTitle("Salary Sorter")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } } }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .task {
                await incomeStore.load()
                await transferStore.load()
                await accountsStore.loadAccounts()
            }
        }
    }

    private var incomeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Income Overview")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text(pendingIncomes.isEmpty ? "No incomes scheduled" : "Active income schedules ready to distribute")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Total Incoming")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(incomeTotal))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ModernTheme.primaryAccent, ModernTheme.secondaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .onTapGesture {
                            copyToClipboard(incomeTotal)
                        }
                }
            }

            if !pendingIncomes.isEmpty {
                VStack(spacing: 10) {
                    ForEach(pendingIncomes, id: \.id) { inc in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [ModernTheme.primaryAccent.opacity(0.75), ModernTheme.secondaryAccent.opacity(0.45)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "banknote")
                                        .foregroundStyle(.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(inc.description)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text(inc.company)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formatCurrency(inc.amount))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(ModernTheme.secondaryAccent)
                                .onTapGesture {
                                    copyToClipboard(inc.amount)
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                                )
                        )
                    }
                }
            }
        }
        .glassCard()
    }
    
    private func destinationGroup(for account: Account) -> some View {
        // Build preview from scheduled transfers (pending, not executed)
        // Include both pending and executed (as long as schedule is active)
        let scheduledToThis = transferStore.schedules.filter { $0.isActive && $0.toAccountId == account.id }
        // Exclude only pot→pot within same account from totals (but show them)
        let internalPotToPot = scheduledToThis.filter { s in
            s.fromAccountId == s.toAccountId && !(s.fromPotName ?? "").isEmpty && !(s.toPotName ?? "").isEmpty
        }
        let included = scheduledToThis.filter { s in
            !(s.fromAccountId == s.toAccountId && !(s.fromPotName ?? "").isEmpty && !(s.toPotName ?? "").isEmpty)
        }
        let potMap = Dictionary(grouping: included.filter { !(($0.toPotName ?? "").isEmpty) }, by: { $0.toPotName ?? "" })
        let mainTransfers = included.filter { ($0.toPotName ?? "").isEmpty }
        let groupTotal = included.reduce(0.0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(account.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Text(formatCurrency(groupTotal))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [ModernTheme.secondaryAccent.opacity(0.25), ModernTheme.primaryAccent.opacity(0.45)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundStyle(ModernTheme.secondaryAccent)
                    .onTapGesture {
                        copyToClipboard(groupTotal)
                    }
            }
            VStack(spacing: 12) {
                // Pot groups (each collapsible)
                let potNames = Array(potMap.keys).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                ForEach(potNames, id: \.self) { potName in
                    let items = potMap[potName] ?? []
                    let key = "acct-\(account.id)-pot-\(potName)"
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(potName)
                                .font(.caption.bold())
                            Spacer()
                            Text(formatCurrency(items.reduce(0) { $0 + $1.amount }))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .onTapGesture {
                                    copyToClipboard(items.reduce(0) { $0 + $1.amount })
                                }
                            Button { togglePot(key) } label: {
                                Image(systemName: expandedPotKeys.contains(key) ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Show transactions and budgets when expanded
                        if expandedPotKeys.contains(key) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(entriesForDestination(accountId: account.id, potName: potName), id: \.id) { entry in
                                    HStack {
                                        Text(entry.title)
                                            .font(.caption2)
                                        if entry.kind == .transaction, let method = entry.method, !method.isEmpty {
                                            let isCard = method == "card"
                                            Text(isCard ? "CARD" : "DD")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background((isCard ? ModernTheme.primaryAccent : ModernTheme.secondaryAccent).opacity(0.18))
                                                .foregroundColor(isCard ? ModernTheme.primaryAccent : ModernTheme.secondaryAccent)
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                        Text(formatCurrency(entry.amount))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .onTapGesture {
                                                copyToClipboard(entry.amount)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                            )
                    )
                }

                // Main account transfers (collapsible)
                if !mainTransfers.isEmpty {
                    let key = account.id
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Main Account")
                                .font(.caption.bold())
                            Spacer()
                            Text(formatCurrency(mainTransfers.reduce(0) { $0 + $1.amount }))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .onTapGesture {
                                    copyToClipboard(mainTransfers.reduce(0) { $0 + $1.amount })
                                }
                            Button { toggleMain(key) } label: {
                                Image(systemName: expandedMainAccounts.contains(key) ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Show transactions and budgets when expanded
                        if expandedMainAccounts.contains(key) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(entriesForDestination(accountId: account.id, potName: nil), id: \.id) { entry in
                                    HStack {
                                        Text(entry.title)
                                            .font(.caption2)
                                        if entry.kind == .transaction, let method = entry.method, !method.isEmpty {
                                            let isCard = method == "card"
                                            Text(isCard ? "CARD" : "DD")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background((isCard ? ModernTheme.primaryAccent : ModernTheme.secondaryAccent).opacity(0.18))
                                                .foregroundColor(isCard ? ModernTheme.primaryAccent : ModernTheme.secondaryAccent)
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                        Text(formatCurrency(entry.amount))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .onTapGesture {
                                                copyToClipboard(entry.amount)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                            )
                    )
                }

                // Internal transfers (shown but not counted; highlighted)
                if !internalPotToPot.isEmpty {
                    HStack {
                        Text("Internal Transfers")
                            .font(.caption.bold())
                        Spacer()
                        Text(formatCurrency(internalPotToPot.reduce(0) { $0 + $1.amount }))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .onTapGesture {
                                copyToClipboard(internalPotToPot.reduce(0) { $0 + $1.amount })
                            }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                            .fill(Color.yellow.opacity(colorScheme == .dark ? 0.18 : 0.28))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 0.8)
                            )
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(internalPotToPot, id: \.id) { s in
                            HStack {
                                let fromLabel = s.fromPotName ?? ""
                                let toLabel = s.toPotName ?? ""
                                Text("\(fromLabel) → \(toLabel)")
                                    .font(.caption)
                                Spacer()
                                Text(formatCurrency(s.amount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .onTapGesture {
                                        copyToClipboard(s.amount)
                                    }
                            }
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private var remainingFooter: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Remaining To Allocate")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.primaryAccent.opacity(0.45), ModernTheme.secondaryAccent.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 72, height: 4)
                    .opacity(0.7)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(remaining >= 0 ? "Ready to distribute" : "Overscheduled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Including active transfers and budgets")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
                Spacer()
                Text(formatCurrency(remaining))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(remaining >= 0 ? ModernTheme.secondaryAccent : ModernTheme.tertiaryAccent)
                    .onTapGesture {
                        copyToClipboard(remaining)
                    }
            }
        }
        .glassCard()
    }

    private func formatCurrency(_ amount: Double) -> String {
        "£" + String(format: "%.2f", abs(amount))
    }

    private func copyToClipboard(_ amount: Double) {
        // Copy only the numeric value (without £ symbol)
        let numericValue = String(format: "%.2f", abs(amount))
        UIPasteboard.general.string = numericValue

        // Show toast with formatted value (with £ symbol for display)
        let formattedValue = formatCurrency(amount)
        toastMessage = "Copied \(formattedValue)"
        withAnimation {
            showToast = true
        }

        // Haptic feedback to indicate successful copy
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Auto-dismiss toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    // Helpers
    private func toggleBudget(_ accountId: Int) { if expandedBudgetAccounts.contains(accountId) { expandedBudgetAccounts.remove(accountId) } else { expandedBudgetAccounts.insert(accountId) } }
    private func toggleMain(_ accountId: Int) { if expandedMainAccounts.contains(accountId) { expandedMainAccounts.remove(accountId) } else { expandedMainAccounts.insert(accountId) } }
    private func togglePot(_ key: String) { if expandedPotKeys.contains(key) { expandedPotKeys.remove(key) } else { expandedPotKeys.insert(key) } }
    private func accountPreviewTotal(_ account: Account) -> Double {
        // Include both pending and executed (active schedules only)
        let scheduledToThis = transferStore.schedules.filter { $0.isActive && $0.toAccountId == account.id }
        let included = scheduledToThis.filter { s in !(s.fromAccountId == s.toAccountId && !(s.fromPotName ?? "").isEmpty && !(s.toPotName ?? "").isEmpty) }
        return included.reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Helper types and functions for entries
    private enum EntryKind { case transaction, budget }
    private struct DestEntry: Identifiable { let id: String; let title: String; let amount: Double; let kind: EntryKind; let method: String? }

    @MainActor
    private func entriesForDestination(accountId: Int, potName: String?) -> [DestEntry] {
        let potKey = potName ?? ""
        let filteredTx = accountsStore.transactions.filter {
            $0.kind == .scheduled && $0.toAccountId == accountId && ($0.toPotName ?? "") == potKey
        }
        let tx: [DestEntry] = filteredTx.map { r in
            let title = r.name.isEmpty ? r.vendor : r.name
            return DestEntry(id: "t-\(r.id)", title: title, amount: r.amount, kind: .transaction, method: r.paymentType)
        }
        var budgets: [DestEntry] = []
        if potName == nil {
            budgets = accountsStore.targets.filter { $0.accountId == accountId }.map { t in DestEntry(id: "b-\(t.id)", title: t.name, amount: t.amount, kind: .budget, method: nil) }
        }
        return tx + budgets
    }
}

#Preview {
    SalarySorterView(isPresented: .constant(true))
        .environmentObject(AccountsStore())
        .environmentObject(IncomeSchedulesStore())
        .environmentObject(TransferSchedulesStore())
}
