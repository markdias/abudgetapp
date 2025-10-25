import SwiftUI

struct SalarySorterView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Binding var isPresented: Bool

    // Show incomes even if executed (include all active incomes)
    private var pendingIncomes: [IncomeSchedule] {
        incomeStore.schedules.filter { $0.isActive }
    }
    private var incomeTotal: Double { pendingIncomes.reduce(0) { $0 + $1.amount } }

    // Collapsible state
    @State private var expandedBudgetAccounts: Set<Int> = []
    @State private var expandedMainAccounts: Set<Int> = []
    @State private var expandedPotKeys: Set<String> = [] // key: "acct-<id>-pot-<name>"

    // Accounts that have any budgets or inbound transactions
    private var destinationAccounts: [Account] {
        accountsStore.accounts.filter { account in
            let hasBudgets = accountsStore.targets.contains { $0.accountId == account.id }
            let hasTx = accountsStore.transactions.contains { $0.toAccountId == account.id }
            return hasBudgets || hasTx
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // Totals across all accounts for remaining calculation
    private var transfersTotal: Double {
        destinationAccounts.reduce(0) { acc, account in
            acc + accountPreviewTotal(account)
        }
    }
    private var remaining: Double { incomeTotal - transfersTotal }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    incomeHeader
                    Divider()
                    Text("Scheduled Transfers").font(.headline)
                    if destinationAccounts.isEmpty {
                        Text("No pending transfer schedules").foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(destinationAccounts, id: \.id) { account in
                                destinationGroup(for: account)
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    remainingFooter
                }
                .padding()
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Salary Sorter")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } } }
            .task {
                await incomeStore.load()
                await transferStore.load()
                await accountsStore.loadAccounts()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var incomeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Income")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(formatCurrency(incomeTotal))
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if pendingIncomes.count == 1, let first = pendingIncomes.first {
                Text(first.company)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if pendingIncomes.count > 1 {
                Text("Multiple sources (\(pendingIncomes.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No pending incomes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func destinationGroup(for account: Account) -> some View {
        // Build preview for this account
        let budgets = accountsStore.targets.filter { $0.accountId == account.id }
        let txToThis = accountsStore.transactions.filter { $0.toAccountId == account.id }
        let potMap = Dictionary(grouping: txToThis.filter { !($0.toPotName ?? "").isEmpty }, by: { $0.toPotName ?? "" })
        let mainTx = txToThis.filter { ($0.toPotName ?? "").isEmpty }
        let groupTotal = budgets.reduce(0) { $0 + $1.amount } + potMap.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.amount } } + mainTx.reduce(0) { $0 + $1.amount }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(account.name)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(formatCurrency(groupTotal))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(spacing: 8) {
                // Budgets group (collapsible)
                if !budgets.isEmpty {
                    let key = account.id
                    HStack {
                        Text("Budgets").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Text(formatCurrency(budgets.reduce(0) { $0 + $1.amount })).font(.caption).foregroundStyle(.secondary)
                        Button { toggleBudget(key) } label: { Image(systemName: expandedBudgetAccounts.contains(key) ? "chevron.up" : "chevron.down").foregroundStyle(.secondary) }
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    if expandedBudgetAccounts.contains(key) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(budgets, id: \.id) { b in
                                HStack { Text(b.name).font(.caption); Spacer(); Text(formatCurrency(b.amount)).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }

                // Pot groups (each collapsible)
                let potNames = Array(potMap.keys).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                ForEach(potNames, id: \.self) { potName in
                    let items = potMap[potName] ?? []
                    let key = "acct-\(account.id)-pot-\(potName)"
                    HStack {
                        Text(potName).font(.caption).fontWeight(.semibold)
                        Spacer()
                        Text(formatCurrency(items.reduce(0) { $0 + $1.amount })).font(.caption).foregroundStyle(.secondary)
                        Button { togglePot(key) } label: { Image(systemName: expandedPotKeys.contains(key) ? "chevron.up" : "chevron.down").foregroundStyle(.secondary) }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    if expandedPotKeys.contains(key) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(items, id: \.id) { r in
                                let title = r.name.isEmpty ? r.vendor : r.name
                                HStack { Text(title).font(.caption); Spacer(); Text(formatCurrency(r.amount)).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }

                // Main account transactions (collapsible)
                if !mainTx.isEmpty {
                    let key = account.id
                    HStack {
                        Text("Main Account").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Text(formatCurrency(mainTx.reduce(0) { $0 + $1.amount })).font(.caption).foregroundStyle(.secondary)
                        Button { toggleMain(key) } label: { Image(systemName: expandedMainAccounts.contains(key) ? "chevron.up" : "chevron.down").foregroundStyle(.secondary) }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    if expandedMainAccounts.contains(key) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(mainTx, id: \.id) { r in
                                let title = r.name.isEmpty ? r.vendor : r.name
                                HStack { Text(title).font(.caption); Spacer(); Text(formatCurrency(r.amount)).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private var remainingFooter: some View {
        HStack {
            Text("Remaining")
                .font(.subheadline).fontWeight(.semibold)
            Spacer()
            Text(formatCurrency(remaining))
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatCurrency(_ amount: Double) -> String {
        "£" + String(format: "%.2f", abs(amount))
    }

    // Helpers
    private func toggleBudget(_ accountId: Int) { if expandedBudgetAccounts.contains(accountId) { expandedBudgetAccounts.remove(accountId) } else { expandedBudgetAccounts.insert(accountId) } }
    private func toggleMain(_ accountId: Int) { if expandedMainAccounts.contains(accountId) { expandedMainAccounts.remove(accountId) } else { expandedMainAccounts.insert(accountId) } }
    private func togglePot(_ key: String) { if expandedPotKeys.contains(key) { expandedPotKeys.remove(key) } else { expandedPotKeys.insert(key) } }
    private func accountPreviewTotal(_ account: Account) -> Double {
        let budgets = accountsStore.targets.filter { $0.accountId == account.id }.reduce(0) { $0 + $1.amount }
        let txToThis = accountsStore.transactions.filter { $0.toAccountId == account.id }
        let pots = txToThis.filter { !($0.toPotName ?? "").isEmpty }.reduce(0) { $0 + $1.amount }
        let main = txToThis.filter { ($0.toPotName ?? "").isEmpty }.reduce(0) { $0 + $1.amount }
        return budgets + pots + main
    }
}

#Preview {
    SalarySorterView(isPresented: .constant(true))
        .environmentObject(AccountsStore())
        .environmentObject(IncomeSchedulesStore())
        .environmentObject(TransferSchedulesStore())
}
