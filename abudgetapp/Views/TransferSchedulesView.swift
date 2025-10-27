import SwiftUI

struct ManageTransferSchedulesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ManageButton(title: "Add Transfer Schedules", color: BrandTheme.accentSecondary, icon: "plus.circle.fill", destination: { AddTransferSchedulesScreen() })
                        ManageButton(title: "Execute Transfer Schedules", color: BrandTheme.accentTertiary, icon: "play.circle.fill", destination: { ExecuteTransferSchedulesScreen() })
                        ManageButton(title: "Completed Transfers", color: BrandTheme.accentQuaternary, icon: "checkmark.circle.fill", destination: { CompletedTransfersScreen() }, disabled: transferStore.schedules.allSatisfy { !$0.isCompleted })
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle("Transfer Schedules")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } } }
            .task { await transferStore.load() }
        }
    }

}

// MARK: - Hub Button
private struct ManageButton<Destination: View>: View {
    let title: String
    let color: Color
    let icon: String
    @ViewBuilder let destination: () -> Destination
    var disabled: Bool = false

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(color.opacity(disabled ? 0.35 : 0.55))
                        .frame(width: 44, height: 44)
                        .shadow(color: color.opacity(0.25), radius: 8, x: 0, y: 4)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
        .brandCardStyle(padding: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(color.opacity(disabled ? 0.18 : 0.3), lineWidth: 1.2)
        )
        .opacity(disabled ? 0.55 : 1)
        .disabled(disabled)
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
        ZStack {
            BrandBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Source")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
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
                    .brandCardStyle()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pot Transfers")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Automatically collect direct debits, card payments, and budgets into matching pots.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
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

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Account Transfers")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Roll budgets and scheduled transactions into the right account before pay day.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
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
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        .navigationTitle("Add Transfers")
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

    private func destinationCard(id: String, name: String, subtitle: String, amount: Double, entries: [DestEntry], buttonTitle: String, existingSchedule: TransferSchedule?, onDelete: @escaping () -> Void, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(formatCurrency(amount))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LinearGradient(colors: [BrandTheme.accentTertiary.opacity(0.22), BrandTheme.accentSecondary.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(action: { toggleExpanded(id) }) {
                    Image(systemName: isExpanded(id) ? "chevron.up" : "chevron.down")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded(id) && !entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { item in
                        HStack(alignment: .center, spacing: 10) {
                            Text(item.title)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if item.kind == .transaction, let method = item.method, !method.isEmpty {
                                Text(method == "direct_debit" ? "DD" : "CARD")
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(method == "direct_debit" ? BrandTheme.accent.opacity(0.18) : Color.white.opacity(0.08))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text(formatCurrency(item.amount))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let _ = existingSchedule {
                HStack {
                    scheduledBadge()
                    Spacer()
                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.red.opacity(0.16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.red.opacity(0.45), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.red.opacity(0.9))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                }
            } else {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [BrandTheme.accentSecondary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
                .shadow(color: BrandTheme.accent.opacity(0.25), radius: 12, x: 0, y: 6)
            }
        }
        .brandCardStyle(padding: 20)
    }

    private func formatCurrency(_ amount: Double) -> String { "£" + String(format: "%.2f", abs(amount)) }
    private func scheduledBadge() -> some View {
        Text("SCHEDULED")
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(BrandTheme.accentTertiary.opacity(0.18))
            .foregroundColor(.white)
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
        ZStack {
            BrandBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Button {
                        Task { await transferStore.executeAll() }
                    } label: {
                        Text("Execute All Transfer Schedules")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(LinearGradient(colors: [BrandTheme.accentSecondary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(.white)
                    .shadow(color: BrandTheme.accent.opacity(0.25), radius: 12, x: 0, y: 6)
                    .opacity(transferStore.schedules.allSatisfy { $0.isCompleted } ? 0.45 : 1)
                    .disabled(transferStore.schedules.allSatisfy { $0.isCompleted })

                    VStack(alignment: .leading, spacing: 16) {
                        Text("By Destination")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        groupedList
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        .navigationTitle("Execute Transfers")
    }

    private var groupedList: some View {
        Group {
            if transferStore.schedules.isEmpty {
                Text("No transfer schedules")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
                    .brandCardStyle()
            } else {
                let groups = Dictionary(grouping: transferStore.schedules.filter { $0.isActive }) { item in
                    GroupKey(toAccountId: item.toAccountId, toPotName: item.toPotName ?? "")
                }
                VStack(spacing: 18) {
                    ForEach(groups.keys.sorted(by: { $0.displayName(accountsStore) < $1.displayName(accountsStore) }), id: \.self) { key in
                        let items = groups[key] ?? []
                        let total = items.reduce(0.0) { $0 + $1.amount }
                        let schedule = scheduleForDestination(accountId: key.toAccountId, potName: key.toPotName.isEmpty ? nil : key.toPotName)
                        let canExecute = {
                            guard let schedule else { return false }
                            return !schedule.isCompleted && canExecuteSchedule(schedule)
                        }()

                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(key.displayName(accountsStore))
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(.primary)

                                    let hasCompleted = (items.first { $0.isCompleted } != nil)
                                    Text("\(hasCompleted ? "Scheduled" : "Total pending") \(formatCurrency(total))")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("\(items.count) items")
                                    .font(.system(.caption2, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.secondary)
                            }

                            if let schedule {
                                HStack(spacing: 12) {
                                    let executeTitle = schedule.isCompleted ? "Executed" : "Execute"
                                    Button(executeTitle) {
                                        Task {
                                            await transferStore.executeGroup(toAccountId: key.toAccountId, toPotName: key.toPotName.isEmpty ? nil : key.toPotName)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: schedule.isCompleted
                                                        ? [Color.gray.opacity(0.35), Color.gray.opacity(0.28)]
                                                        : [BrandTheme.accentTertiary, BrandTheme.accentSecondary],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                    .foregroundColor(.white)
                                    .opacity(canExecute ? 1 : 0.45)
                                    .disabled(!canExecute)

                                    Button("Delete") {
                                        Task { await transferStore.delete(schedule: schedule) }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.red.opacity(0.16))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(Color.red.opacity(0.45), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.red.opacity(0.9))
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(items, id: \.id) { item in
                                    HStack {
                                        Text("From: \(sourceLabel(for: item))")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(formatCurrency(item.amount))
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        if item.isCompleted {
                                            Text("Executed")
                                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                                .foregroundStyle(.green)
                                        } else if !canExecuteSchedule(item) {
                                            Text("Insufficient funds")
                                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                            }
                        }
                        .brandCardStyle(padding: 20)
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
            $0.kind == .scheduled && $0.toAccountId == accountId && ($0.toPotName ?? "") == potKey
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
        ZStack {
            BrandBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if sourceAccount == nil || (executedIncomes.isEmpty && flowSteps.isEmpty) {
                        ContentUnavailableView(
                            "No Completed Transfers",
                            systemImage: "checkmark.seal",
                            description: Text("Run executions to see history here.")
                        )
                        .brandCardStyle()
                    } else {
                        incomeSummaryCard
                        allocationFlowCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        .navigationTitle("Completed Transfers")
    }

    private var incomeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Income into \(sourceAccountName)")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sourceAccountName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("Total executed income")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("+\(formatCurrency(sourceIncomeTotal))")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [BrandTheme.accentTertiary.opacity(0.25), BrandTheme.accentSecondary.opacity(0.18)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .brandCardStyle(padding: 22)
    }

    private var allocationFlowCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allocation Flow")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(annotatedSteps) { row in
                let step = row.step

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(step.path)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        if let tag = step.methodTag, !tag.isEmpty {
                            Text(tag)
                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    tag == "BUDGET"
                                    ? Color.white.opacity(0.08)
                                    : BrandTheme.accent.opacity(0.18)
                                )
                                .foregroundColor(tag == "BUDGET" ? .secondary : .white)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text("-\(formatCurrency(step.amount))")
                            .font(.system(.caption, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(LinearGradient(colors: [BrandTheme.accent.opacity(0.18), BrandTheme.accentSecondary.opacity(0.14)], startPoint: .leading, endPoint: .trailing))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if !step.date.isEmpty {
                        Text(formattedDate(step.date))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Remaining in \(sourceAccountName)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatCurrency(row.remainingAfter))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.1))
            }

            HStack {
                Text("Final Balance in \(sourceAccountName)")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Spacer()
                Text(formatCurrency(finalRemaining))
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(LinearGradient(colors: [BrandTheme.accentSecondary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing))
            }
            .padding(.top, 8)
        }
        .brandCardStyle(padding: 22)
    }
}

#Preview {
    let accounts = AccountsStore()
    let transferStore = TransferSchedulesStore(accountsStore: accounts)
    return ManageTransferSchedulesView(isPresented: .constant(true))
        .environmentObject(accounts)
        .environmentObject(transferStore)
}
