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

    // Collapsible state and grouped accounts
    @State private var expandedBudgetAccounts: Set<Int> = []
    @State private var expandedMainAccounts: Set<Int> = []
    @State private var expandedPotKeys: Set<String> = [] // key: "acct-<id>-pot-<name>"

    private var destinationAccounts: [Account] {
        accountsStore.accounts.filter { account in
            let hasBudgets = accountsStore.targets.contains { $0.accountId == account.id }
            let hasTx = accountsStore.transactions.contains { $0.toAccountId == account.id }
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

                    NavigationLink {
                        CompletedTransfersScreen()
                    } label: {
                        Text("Completed Transfers")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Color.gray.opacity(hasCompletedTransfers ? 1.0 : 0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .gray.opacity(0.18), radius: 6, x: 0, y: 3)
                    }
                    .disabled(!hasCompletedTransfers)

                    // Debug footer: show source filename for clarity
                    Text("File: abudgetapp/Views/SalarySorterView.swift")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

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
            if pendingIncomes.isEmpty {
                Text("No incomes").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(pendingIncomes, id: \.id) { inc in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(inc.description).font(.caption)
                                Text(inc.company).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formatCurrency(inc.amount)).font(.caption).foregroundStyle(.secondary)
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
                            ForEach(items, id: \.id) { s in
                                HStack {
                                    Text(s.description).font(.caption)
                                    Spacer()
                                    Text(formatCurrency(s.amount)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Main account transfers (collapsible)
                if !mainTransfers.isEmpty {
                    let key = account.id
                    HStack {
                        Text("Main Account").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Text(formatCurrency(mainTransfers.reduce(0) { $0 + $1.amount })).font(.caption).foregroundStyle(.secondary)
                        Button { toggleMain(key) } label: { Image(systemName: expandedMainAccounts.contains(key) ? "chevron.up" : "chevron.down").foregroundStyle(.secondary) }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    if expandedMainAccounts.contains(key) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(mainTransfers, id: \.id) { s in
                                HStack { Text(s.description).font(.caption); Spacer(); Text(formatCurrency(s.amount)).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }

                // Internal transfers (shown but not counted; highlighted)
                if !internalPotToPot.isEmpty {
                    HStack {
                        Text("Internal Transfers").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Text(formatCurrency(internalPotToPot.reduce(0) { $0 + $1.amount }))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(internalPotToPot, id: \.id) { s in
                            HStack {
                                let fromLabel = s.fromPotName ?? ""
                                let toLabel = s.toPotName ?? ""
                                Text("\(fromLabel) → \(toLabel)").font(.caption)
                                Spacer()
                                Text(formatCurrency(s.amount)).font(.caption).foregroundStyle(.secondary)
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
        // Include both pending and executed (active schedules only)
        let scheduledToThis = transferStore.schedules.filter { $0.isActive && $0.toAccountId == account.id }
        let included = scheduledToThis.filter { s in !(s.fromAccountId == s.toAccountId && !(s.fromPotName ?? "").isEmpty && !(s.toPotName ?? "").isEmpty) }
        return included.reduce(0.0) { $0 + $1.amount }
    }

    // (Transfer flows moved to CompletedTransfersScreen)
}

#Preview {
    SalarySorterView(isPresented: .constant(true))
        .environmentObject(AccountsStore())
        .environmentObject(IncomeSchedulesStore())
        .environmentObject(TransferSchedulesStore())
}
