import SwiftUI

struct ManageTransferSchedulesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ManageButton(title: "Add Transfer Schedules", color: .blue, destination: { AddTransferSchedulesScreen() })
                    ManageButton(title: "Execute Transfer Schedules", color: .purple, destination: { ExecuteTransferSchedulesScreen() })
                    ManageButton(title: "Completed Transfers", color: .gray, destination: { CompletedTransfersScreen() }, disabled: transferStore.schedules.allSatisfy { !$0.isCompleted })
                }
                .frame(maxWidth: 420)
                .padding()
            }
            .navigationTitle("Transfer Schedules")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } } }
            .task { await transferStore.load() }
            .background(Color(.systemGroupedBackground))
        }
    }

}

// MARK: - Hub Button
private struct ManageButton<Destination: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let destination: () -> Destination
    var disabled: Bool = false

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundStyle(.white)
                .background(color.opacity(disabled ? 0.4 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: color.opacity(0.18), radius: 8, x: 0, y: 4)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Add Screen
private struct AddTransferSchedulesScreen: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    enum Source: Hashable, Identifiable { case none, account(Int), pot(Int, String); var id: String { switch self { case .none: return "none"; case .account(let id): return "a-\(id)"; case .pot(let id, let p): return "p-\(id)-\(p)" } } }
    @State private var source: Source = .none
    @State private var expandedCards: Set<String> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Source").font(.subheadline).fontWeight(.semibold)
                    Picker("Select source", selection: $source) {
                        Text("None").tag(Source.none)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(Source.account(account.id))
                            if let pots = account.pots {
                                ForEach(pots, id: \.name) { pot in
                                    Text("\(account.name) • \(pot.name)").tag(Source.pot(account.id, pot.name))
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text("Available Transfers").font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pot Transfers").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(potDestinations, id: \.id) { dest in
                        let entries = entriesForDestination(accountId: dest.accountId, potName: dest.potName)
                        let total = entries.reduce(0.0) { $0 + $1.amount }
                        let existing = scheduleForDestination(accountId: dest.accountId, potName: dest.potName)
                        destinationCard(id: dest.id,
                                        name: dest.title,
                                        subtitle: dest.subtitle,
                                        amount: total,
                                        entries: entries,
                                        buttonTitle: "Schedule Transfer (\(formatCurrency(total)))",
                                        existingSchedule: existing,
                                        onDelete: {
                                            if let s = existing { Task { await transferStore.delete(schedule: s) } }
                                        }) {
                            let src: (Int, String?)
                            switch source {
                            case .none: return
                            case .account(let id): src = (id, nil)
                            case .pot(let id, let pot): src = (id, pot)
                            }
                            Task { await transferStore.addSchedule(from: src.0, fromPotName: src.1, to: dest.accountId, toPotName: dest.potName, amount: total, description: dest.title) }
                        }
                        .disabled(source == .none || total <= 0)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Transfers").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(accountDestinations, id: \.id) { dest in
                        let entries = entriesForDestination(accountId: dest.accountId, potName: nil)
                        let total = entries.reduce(0.0) { $0 + $1.amount }
                        let existing = scheduleForDestination(accountId: dest.accountId, potName: nil)
                        destinationCard(id: dest.id,
                                        name: dest.title,
                                        subtitle: dest.subtitle,
                                        amount: total,
                                        entries: entries,
                                        buttonTitle: "Schedule Transfer (\(formatCurrency(total)))",
                                        existingSchedule: existing,
                                        onDelete: {
                                            if let s = existing { Task { await transferStore.delete(schedule: s) } }
                                        }) {
                            let src: (Int, String?)
                            switch source {
                            case .none: return
                            case .account(let id): src = (id, nil)
                            case .pot(let id, let pot): src = (id, pot)
                            }
                            Task { await transferStore.addSchedule(from: src.0, fromPotName: src.1, to: dest.accountId, toPotName: nil, amount: total, description: dest.title) }
                        }
                        .disabled(source == .none || total <= 0)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Add Transfers")
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Add helpers
    private struct Destination: Hashable { let id: String; let accountId: Int; let potName: String?; let title: String; let subtitle: String }
    private enum EntryKind { case transaction, budget }
    private struct DestEntry: Identifiable { let id: String; let title: String; let amount: Double; let kind: EntryKind; let method: String? }

    private var potDestinations: [Destination] {
        accountsStore.accounts.flatMap { account in
            let pots = account.pots ?? []
            return pots.map { pot in
                let entries = entriesForDestination(accountId: account.id, potName: pot.name)
                let txEntries = entries.filter { $0.kind == .transaction }
                let ddCount = txEntries.filter { ($0.method ?? "") == "direct_debit" }.count
                let cardCount = txEntries.filter { ($0.method ?? "").contains("card") }.count
                let bdgCount = entries.filter { $0.kind == .budget }.count
                let subtitle = "\(account.accountType ?? account.type.capitalized)\n\(ddCount) Direct Debits, \(cardCount) Card Payments, \(bdgCount) Budgets"
                return Destination(id: "pot-\(account.id)-\(pot.id)", accountId: account.id, potName: pot.name, title: pot.name, subtitle: subtitle)
            }
        }
    }

    private var accountDestinations: [Destination] {
        accountsStore.accounts.map { account in
            let entries = entriesForDestination(accountId: account.id, potName: nil)
            let txEntries = entries.filter { $0.kind == .transaction }
            let ddCount = txEntries.filter { ($0.method ?? "") == "direct_debit" }.count
            let cardCount = txEntries.filter { ($0.method ?? "").contains("card") }.count
            let bdgCount = entries.filter { $0.kind == .budget }.count
            let subtitle = "\(account.accountType ?? account.type.capitalized)\n\(ddCount) Direct Debits, \(cardCount) Card Payments, \(bdgCount) Budgets"
            return Destination(id: "acct-\(account.id)", accountId: account.id, potName: nil, title: account.name, subtitle: subtitle)
        }
    }

    @MainActor
    private func entriesForDestination(accountId: Int, potName: String?) -> [DestEntry] {
        let potKey = potName ?? ""
        let filteredTx = accountsStore.transactions.filter { $0.toAccountId == accountId && ($0.toPotName ?? "") == potKey }
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

    private func destinationCard(id: String, name: String, subtitle: String, amount: Double, entries: [DestEntry], buttonTitle: String, existingSchedule: TransferSchedule?, onDelete: @escaping () -> Void, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.subheadline).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Text(formatCurrency(amount))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Button(action: { toggleExpanded(id) }) {
                    Image(systemName: isExpanded(id) ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
                }
            }
            if isExpanded(id) && !entries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entries) { item in
                        HStack {
                            Text(item.title)
                                .font(.caption)
                            if item.kind == .transaction, let method = item.method, !method.isEmpty {
                                Text(method == "direct_debit" ? "DD" : "CARD")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(method == "direct_debit" ? Color.purple.opacity(0.15) : Color.gray.opacity(0.15))
                                    .foregroundColor(method == "direct_debit" ? .purple : .secondary)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text(formatCurrency(item.amount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let _ = existingSchedule {
                HStack {
                    scheduledBadge()
                    Spacer()
                    Button("Delete", role: .destructive, action: onDelete).buttonStyle(.borderedProminent).tint(.red)
                }
            } else {
                Button(buttonTitle, action: action)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func formatCurrency(_ amount: Double) -> String { "£" + String(format: "%.2f", abs(amount)) }
    private func scheduledBadge() -> some View {
        Text("SCHEDULED")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
    }
    private func toggleExpanded(_ id: String) { if expandedCards.contains(id) { expandedCards.remove(id) } else { expandedCards.insert(id) } }
    private func isExpanded(_ id: String) -> Bool { expandedCards.contains(id) }
    private func scheduleForDestination(accountId: Int, potName: String?) -> TransferSchedule? {
        let key = potName ?? ""
        return transferStore.schedules.first { $0.isActive && $0.toAccountId == accountId && ($0.toPotName ?? "") == key }
    }
}

// MARK: - Execute Screen
private struct ExecuteTransferSchedulesScreen: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    Task { await transferStore.executeAll() }
                } label: {
                    Text("Execute All Transfer Schedules")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(transferStore.schedules.allSatisfy { $0.isCompleted })

                Text("By Destination").font(.headline)
                groupedList
            }
            .padding()
        }
        .navigationTitle("Execute Transfers")
        .background(Color(.systemGroupedBackground))
    }

    private var groupedList: some View {
        Group {
            if transferStore.schedules.isEmpty {
                Text("No transfer schedules").foregroundStyle(.secondary)
            } else {
                let groups = Dictionary(grouping: transferStore.schedules.filter { $0.isActive }) { item in
                    return GroupKey(toAccountId: item.toAccountId, toPotName: item.toPotName ?? "")
                }
                VStack(spacing: 12) {
                    ForEach(groups.keys.sorted(by: { $0.displayName(accountsStore) < $1.displayName(accountsStore) }), id: \.self) { key in
                        let items = groups[key] ?? []
                        let total = items.reduce(0.0) { $0 + $1.amount }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(key.displayName(accountsStore)).font(.subheadline).fontWeight(.semibold)
                                    let hasCompleted = (items.first { $0.isCompleted } != nil)
                                    Text("\(hasCompleted ? "Scheduled" : "Total pending"): £\(String(format: "%.2f", total))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                VStack(spacing: 8) {
                                    let schedule = scheduleForDestination(accountId: key.toAccountId, potName: key.toPotName.isEmpty ? nil : key.toPotName)
                                    let canExecute = (schedule != nil) && !(schedule!.isCompleted) && canExecuteSchedule(schedule!)
                                    Button((schedule?.isCompleted ?? false) ? "Executed" : "Execute") {
                                        Task { await transferStore.executeGroup(toAccountId: key.toAccountId, toPotName: key.toPotName.isEmpty ? nil : key.toPotName) }
                                    }
                                    .disabled(!(canExecute))
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    if let schedule = schedule {
                                        
                                        Button("Delete", role: .destructive) { Task { await transferStore.delete(schedule: schedule) } }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.red)
                                    }
                                }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(items, id: \.id) { item in
                                    HStack {
                                        Text("From: \(sourceLabel(for: item))").font(.caption)
                                        Spacer()
                                        Text(formatCurrency(item.amount)).font(.caption).foregroundStyle(.secondary)
                                        if item.isCompleted {
                                            Text("Executed").font(.caption2).foregroundStyle(.green)
                                        } else if !canExecuteSchedule(item) {
                                            Text("Insufficient funds").font(.caption2).foregroundStyle(.red)
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
                }
            }
        }
    }

    private struct GroupKey: Hashable {
        let toAccountId: Int
        let toPotName: String
        @MainActor
        func displayName(_ accountsStore: AccountsStore) -> String {
            let accountName = accountsStore.accounts.first(where: { $0.id == toAccountId })?.name ?? "Account #\(toAccountId)"
            if toPotName.isEmpty { return accountName }
            return "\(accountName) • \(toPotName)"
        }
    }

    private func scheduleForDestination(accountId: Int, potName: String?) -> TransferSchedule? {
        let key = potName ?? ""
        return transferStore.schedules.first { $0.isActive && $0.toAccountId == accountId && ($0.toPotName ?? "") == key }
    }
    private func canExecuteSchedule(_ schedule: TransferSchedule) -> Bool {
        guard let source = accountsStore.accounts.first(where: { $0.id == schedule.fromAccountId }) else { return false }
        if let fromPot = schedule.fromPotName, !fromPot.isEmpty {
            guard let pots = source.pots, let pot = pots.first(where: { $0.name == fromPot }) else { return false }
            return pot.balance >= schedule.amount
        }
        return source.balance >= schedule.amount
    }
    private func sourceLabel(for schedule: TransferSchedule) -> String {
        let acct = accountName(schedule.fromAccountId)
        if let pot = schedule.fromPotName, !pot.isEmpty { return "\(acct) • \(pot)" }
        return acct
    }
    private func accountName(_ id: Int) -> String {
        accountsStore.accounts.first(where: { $0.id == id })?.name ?? "Account #\(id)"
    }
    private func formatCurrency(_ amount: Double) -> String { "£" + String(format: "%.2f", abs(amount)) }
}

// MARK: - Completed Screen
struct CompletedTransfersScreen: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore

    // All completed transfers, sorted by execution time
    private var completedTransfers: [TransferSchedule] {
        transferStore.schedules
            .filter { $0.isActive && $0.isCompleted }
            .filter { $0.lastExecuted != nil }
            .sorted { ($0.lastExecuted ?? "") < ($1.lastExecuted ?? "") }
    }

    // The source account is the account money left from.
    // We take the first completed transfer's fromAccountId as the "salary source".
    private var sourceAccountId: Int? {
        completedTransfers.first?.fromAccountId
    }

    private var sourceAccount: Account? {
        if let id = sourceAccountId {
            return accountsStore.account(for: id)
        }
        return nil
    }

    private var sourceAccountName: String {
        sourceAccount?.name ?? "Account"
    }

    // All executed incomes paid into that same source account
    private var executedIncomes: [IncomeSchedule] {
        incomeStore.schedules
            .filter { $0.isActive && $0.isCompleted }
            .filter { $0.accountId == sourceAccountId }
            .sorted { ($0.lastExecuted ?? "") < ($1.lastExecuted ?? "") }
    }

    // Total income that actually landed in that source account
    private var sourceIncomeTotal: Double {
        executedIncomes.reduce(0) { $0 + $1.amount }
    }

    // MARK: Supporting models for breakdown

    private enum EntryKind { case transaction, budget }

    // Represents an individual transaction or budget item that fed into a transfer schedule
    private struct DestEntry {
        let id: String
        let title: String
        let amount: Double
        let kind: EntryKind
        let method: String?
    }

    // Represents a flattened "flow step": source account -> destination (account / pot) -> specific item
    private struct FlowStep: Identifiable {
        let id: String
        let path: String
        let date: String
        let amount: Double
        let methodTag: String?
        var formattedDate: String { date }
    }

    // Build the list of individual items (transactions and budgets) for a given destination account / pot.
    // This mirrors entriesForDestination from AddTransferSchedulesScreen.
    @MainActor
    private func entriesForDestination(accountId: Int, potName: String?) -> [DestEntry] {
        let potKey = potName ?? ""
        let filteredTx = accountsStore.transactions.filter {
            $0.toAccountId == accountId && ($0.toPotName ?? "") == potKey
        }
        let tx: [DestEntry] = filteredTx.map { r in
            let title = r.name.isEmpty ? r.vendor : r.name
            return DestEntry(
                id: "t-\(r.id)",
                title: title,
                amount: r.amount,
                kind: .transaction,
                method: r.paymentType
            )
        }

        var budgets: [DestEntry] = []
        if potName == nil {
            budgets = accountsStore.targets
                .filter { $0.accountId == accountId }
                .map { t in
                    DestEntry(
                        id: "b-\(t.id)",
                        title: t.name,
                        amount: t.amount,
                        kind: .budget,
                        method: nil
                    )
                }
        }

        return tx + budgets
    }

    // Flatten all completed transfers from the source account into flow steps,
    // where each step is a single transaction or budget item.
    private var flowSteps: [FlowStep] {
        guard let sourceId = sourceAccountId else { return [] }

        // We only care about transfers that left the source account
        let schedulesFromSource = completedTransfers
            .filter { $0.fromAccountId == sourceId }
            .sorted {
                // order by execution date, then destination account name, then pot name
                let lDate = $0.lastExecuted ?? ""
                let rDate = $1.lastExecuted ?? ""
                if lDate != rDate { return lDate < rDate }
                let lAcc = accountsStore.account(for: $0.toAccountId)?.name ?? ""
                let rAcc = accountsStore.account(for: $1.toAccountId)?.name ?? ""
                if lAcc != rAcc { return lAcc < rAcc }
                let lPot = $0.toPotName ?? ""
                let rPot = $1.toPotName ?? ""
                return lPot < rPot
            }

        let srcName = sourceAccountName

        var steps: [FlowStep] = []

        for sched in schedulesFromSource {
            let destAccountName = accountsStore.account(for: sched.toAccountId)?.name ?? "Account #\(sched.toAccountId)"
            let destLabel: String = {
                if let pot = sched.toPotName, !pot.isEmpty {
                    return pot
                } else {
                    return destAccountName
                }
            }()

            // pull the underlying transaction / budget entries that this transfer schedule represented
            let entries = entriesForDestination(accountId: sched.toAccountId, potName: sched.toPotName)

            for entry in entries {
                // choose a tag for the chip (DD, CARD, BUDGET)
                let tag: String? = {
                    switch entry.kind {
                    case .transaction:
                        if let m = entry.method, !m.isEmpty {
                            if m == "direct_debit" { return "DD" }
                            if m.contains("card") { return "CARD" }
                            return m.uppercased()
                        }
                        return nil
                    case .budget:
                        return "BUDGET"
                    }
                }()

                let chain = "\(srcName) → \(destLabel) → \(entry.title)"
                steps.append(
                    FlowStep(
                        id: "sched-\(sched.id)-\(entry.id)",
                        path: chain,
                        date: sched.lastExecuted ?? "",
                        amount: entry.amount,
                        methodTag: tag
                    )
                )
            }
        }

        return steps
    }

    // A flow step plus the remaining balance after applying it
    private struct AnnotatedStep: Identifiable {
        let step: FlowStep
        let remainingAfter: Double
        var id: String { step.id }
    }

    // Build a list where each row knows the remaining balance after that transaction/budget item.
    private var annotatedSteps: [AnnotatedStep] {
        var running = incomeTotalForDisplay
        return flowSteps.map { step in
            running -= step.amount
            return AnnotatedStep(step: step, remainingAfter: max(running, 0))
        }
    }

    // Convenience for the final balance after all allocations
    private var finalRemaining: Double {
        annotatedSteps.last?.remainingAfter ?? incomeTotalForDisplay
    }

    // For annotatedSteps, use the same as sourceIncomeTotal for the starting value
    private var incomeTotalForDisplay: Double {
        sourceIncomeTotal
    }

    // MARK: Formatting helpers

    private func formatCurrency(_ amount: Double) -> String {
        "£" + String(format: "%.2f", abs(amount))
    }

    private func formattedDate(_ iso: String) -> String {
        if let date = ISO8601DateFormatter().date(from: iso) {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f.string(from: date)
        }
        return iso
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if sourceAccount == nil || (executedIncomes.isEmpty && flowSteps.isEmpty) {
                    ContentUnavailableView(
                        "No Completed Transfers",
                        systemImage: "checkmark.seal",
                        description: Text("Run executions to see history here.")
                    )
                } else {
                    // 1. Income into source account
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Income into \(sourceAccountName)")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sourceAccountName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Total Executed Income")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(formatCurrency(sourceIncomeTotal))")
                                .font(.title3)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.17))
                                .foregroundColor(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.06))
                    )

                    // 2. Allocation Flow, item by item
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Allocation Flow")
                            .font(.headline)
                            .padding(.bottom, 8)

                        ForEach(annotatedSteps) { row in
                            let step = row.step

                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(step.path)
                                            .font(.subheadline)
                                        if let tag = step.methodTag, !tag.isEmpty {
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    tag == "BUDGET"
                                                    ? Color.gray.opacity(0.15)
                                                    : Color.purple.opacity(0.15)
                                                )
                                                .foregroundColor(
                                                    tag == "BUDGET"
                                                    ? .secondary
                                                    : .purple
                                                )
                                                .clipShape(Capsule())
                                        }
                                    }

                                    if !step.date.isEmpty {
                                        Text(formattedDate(step.date))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text("-\(formatCurrency(step.amount))")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundColor(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            HStack {
                                Text("Remaining in \(sourceAccountName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatCurrency(row.remainingAfter))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()
                                .padding(.vertical, 2)
                        }

                        // Final row
                        HStack {
                            Text("Final Balance in \(sourceAccountName)")
                                .font(.headline)
                            Spacer()
                            Text(formatCurrency(finalRemaining))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.06))
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Completed Transfers")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    let accounts = AccountsStore()
    let transferStore = TransferSchedulesStore(accountsStore: accounts)
    return ManageTransferSchedulesView(isPresented: .constant(true))
        .environmentObject(accounts)
        .environmentObject(transferStore)
}
