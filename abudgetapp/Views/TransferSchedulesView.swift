import SwiftUI

struct ManageTransferSchedulesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ManageButton(title: "Add Transfer Schedules", icon: "plus.circle.fill", gradient: [ModernTheme.primaryAccent, Color(red: 0.32, green: 0.72, blue: 1.0)]) {
                            AddTransferSchedulesScreen()
                        }
                        ManageButton(title: "Execute Transfer Schedules", icon: "play.circle.fill", gradient: [ModernTheme.secondaryAccent, ModernTheme.primaryAccent]) {
                            ExecuteTransferSchedulesScreen()
                        }
                        ManageButton(
                            title: "Completed Transfers",
                            icon: "checkmark.seal.fill",
                            gradient: [Color(red: 0.76, green: 0.38, blue: 0.98), ModernTheme.tertiaryAccent],
                            destination:  {
                                CompletedTransfersScreen()
                            }, disabled: transferStore.schedules.allSatisfy { !$0.isCompleted })
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Transfer Schedules")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } } }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .task { await transferStore.load() }
        }
    }

}

// MARK: - Hub Button
private struct ManageButton<Destination: View>: View {
    let title: String
    let icon: String
    let gradient: [Color]
    @ViewBuilder let destination: () -> Destination
    @Environment(\.colorScheme) private var colorScheme
    var disabled: Bool = false

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    gradient.first?.opacity(disabled ? 0.4 : 1.0) ?? ModernTheme.primaryAccent,
                                    gradient.last?.opacity(disabled ? 0.25 : 0.7) ?? ModernTheme.secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                        )
                    Image(systemName: icon)
                        .foregroundStyle(.white)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: ModernTheme.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(disabled ? 0.35 : 0.9) } + [Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernTheme.cardCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.25 : 0.14), lineWidth: 0.8)
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.18), radius: 22, x: 0, y: 16)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Add Screen
private struct AddTransferSchedulesScreen: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Environment(\.colorScheme) private var colorScheme
    enum Source: Hashable, Identifiable { case none, account(Int), pot(Int, String); var id: String { switch self { case .none: return "none"; case .account(let id): return "a-\(id)"; case .pot(let id, let p): return "p-\(id)-\(p)" } } }
    @State private var source: Source = .none
    @State private var expandedCards: Set<String> = []

    var body: some View {
        ZStack {
            ModernTheme.background(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    sourceSelectionCard
                    potTransfersCard
                    accountTransfersCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: 600)
            }
        }
        .navigationTitle("Add Transfers")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }

    private var sourceSelectionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Select Source")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.secondaryAccent.opacity(0.4), ModernTheme.primaryAccent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 70, height: 4)
                    .opacity(0.6)
            }

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
            .frame(maxWidth: .infinity)
        }
        .glassCard()
    }

    private var potTransfersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pot Transfers")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
            }

            if potDestinations.isEmpty {
                ContentUnavailableView(
                    "No pot destinations",
                    systemImage: "tray",
                    description: Text("Create pots in your accounts to transfer funds to them.")
                )
            } else {
                VStack(spacing: 12) {
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
                            // Check if destination account is a credit card
                            let isCreditCard = accountsStore.accounts.first(where: { $0.id == dest.accountId })?.isCredit ?? false
                            let linkedCreditId = isCreditCard ? dest.accountId : nil
                            Task { await transferStore.addSchedule(from: src.0, fromPotName: src.1, to: dest.accountId, toPotName: dest.potName, amount: total, description: dest.title, linkedCreditAccountId: linkedCreditId) }
                        }
                        .disabled(source == .none || total <= 0)
                    }
                }
            }
        }
        .glassCard()
    }

    private var accountTransfersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Account Transfers")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
            }

            VStack(spacing: 12) {
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
                        // Check if destination account is a credit card
                        let isCreditCard = accountsStore.accounts.first(where: { $0.id == dest.accountId })?.isCredit ?? false
                        let linkedCreditId = isCreditCard ? dest.accountId : nil
                        Task { await transferStore.addSchedule(from: src.0, fromPotName: src.1, to: dest.accountId, toPotName: nil, amount: total, description: dest.title, linkedCreditAccountId: linkedCreditId) }
                    }
                    .disabled(source == .none || total <= 0)
                }
            }
        }
        .glassCard()
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
                let creditIndicator = account.isCredit ? " • Credit Card" : ""
                let subtitle = "\(account.accountType ?? account.type.capitalized)\(creditIndicator)\n\(ddCount) Direct Debits, \(cardCount) Card Payments, \(bdgCount) Budgets"
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
            let creditIndicator = account.isCredit ? " • Credit Card" : ""
            let subtitle = "\(account.accountType ?? account.type.capitalized)\(creditIndicator)\n\(ddCount) Direct Debits, \(cardCount) Card Payments, \(bdgCount) Budgets"
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.primaryAccent.opacity(0.75), ModernTheme.secondaryAccent.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.white)
                            .font(.headline)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(formatCurrency(amount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ModernTheme.secondaryAccent)
                    Button(action: { toggleExpanded(id) }) {
                        Image(systemName: isExpanded(id) ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .foregroundStyle(ModernTheme.primaryAccent)
                            .font(.caption)
                    }
                }
            }

            if isExpanded(id) && !entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { item in
                        HStack {
                            Text(item.title)
                                .font(.caption)
                            if item.kind == .transaction, let method = item.method, !method.isEmpty {
                                Text(method == "direct_debit" ? "DD" : "CARD")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(method == "direct_debit" ? ModernTheme.secondaryAccent.opacity(0.18) : Color.gray.opacity(0.18))
                                    )
                                    .foregroundStyle(method == "direct_debit" ? ModernTheme.secondaryAccent : .secondary)
                            }
                            Spacer()
                            Text(formatCurrency(item.amount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 4)
            }

            if let _ = existingSchedule {
                HStack(spacing: 12) {
                    Text("Scheduled")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ModernTheme.secondaryAccent.opacity(0.18))
                        )
                        .foregroundStyle(ModernTheme.secondaryAccent)
                    Spacer()
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text("Delete")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ModernTheme.tertiaryAccent)
                }
            } else {
                Button {
                    action()
                } label: {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ModernTheme.primaryAccent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                )
        )
    }

    private func formatCurrency(_ amount: Double) -> String { "£" + String(format: "%.2f", abs(amount)) }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ModernTheme.background(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    executeAllCard
                    transfersByDestinationCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: 600)
            }
        }
        .navigationTitle("Execute Transfers")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }

    private var executeAllCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Execute All Transfers")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.secondaryAccent.opacity(0.4), ModernTheme.primaryAccent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 70, height: 4)
                    .opacity(0.6)
            }

            Button {
                Task { await transferStore.executeAll() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                    Text("Execute All")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.primaryAccent, ModernTheme.secondaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(transferStore.schedules.allSatisfy { $0.isCompleted })
            .opacity(transferStore.schedules.allSatisfy { $0.isCompleted } ? 0.6 : 1)
        }
        .glassCard()
    }

    private var transfersByDestinationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transfers by Destination")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
            }

            groupedList
        }
        .glassCard()
    }

    private var groupedList: some View {
        Group {
            if transferStore.schedules.isEmpty {
                ContentUnavailableView(
                    "No transfer schedules",
                    systemImage: "calendar",
                    description: Text("Create transfer schedules to see them here.")
                )
            } else {
                let groups = Dictionary(grouping: transferStore.schedules.filter { $0.isActive }) { item in
                    return GroupKey(toAccountId: item.toAccountId, toPotName: item.toPotName ?? "")
                }
                VStack(spacing: 12) {
                    ForEach(groups.keys.sorted(by: { $0.displayName(accountsStore) < $1.displayName(accountsStore) }), id: \.self) { key in
                        let items = groups[key] ?? []
                        let total = items.reduce(0.0) { $0 + $1.amount }
                        let schedule = scheduleForDestination(accountId: key.toAccountId, potName: key.toPotName.isEmpty ? nil : key.toPotName)
                        let isCompleted = schedule?.isCompleted ?? false
                        let hasInsufficientFunds = schedule != nil && !isCompleted && !canExecuteSchedule(schedule!)

                        HStack(alignment: .top, spacing: 16) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            isCompleted ? Color.green.opacity(0.75) : hasInsufficientFunds ? ModernTheme.tertiaryAccent.opacity(0.75) : ModernTheme.primaryAccent.opacity(0.75),
                                            isCompleted ? Color.green.opacity(0.35) : hasInsufficientFunds ? ModernTheme.tertiaryAccent.opacity(0.45) : ModernTheme.secondaryAccent.opacity(0.45)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: isCompleted ? "checkmark.seal.fill" : hasInsufficientFunds ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                                        .foregroundStyle(.white)
                                        .font(.headline)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(key.displayName(accountsStore))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("£\(String(format: "%.2f", total))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(ModernTheme.secondaryAccent)

                                // Show sources
                                ForEach(items, id: \.id) { item in
                                    HStack {
                                        Text("From: \(sourceLabel(for: item))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if item.isCompleted {
                                            Text("Executed")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.green.opacity(0.18))
                                                )
                                                .foregroundStyle(.green)
                                        } else if !canExecuteSchedule(item) {
                                            Text("No Funds")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule()
                                                        .fill(ModernTheme.tertiaryAccent.opacity(0.18))
                                                )
                                                .foregroundStyle(ModernTheme.tertiaryAccent)
                                        }
                                    }
                                }
                            }

                            Spacer()

                            VStack(spacing: 10) {
                                let canExecute = (schedule != nil) && !(schedule!.isCompleted) && canExecuteSchedule(schedule!)
                                Button(isCompleted ? "Executed" : "Execute") {
                                    Task { await transferStore.executeGroup(toAccountId: key.toAccountId, toPotName: key.toPotName.isEmpty ? nil : key.toPotName) }
                                }
                                .disabled(!canExecute)
                                .buttonStyle(.borderedProminent)
                                .tint(isCompleted ? .gray : ModernTheme.secondaryAccent)

                                if let schedule = schedule {
                                    Button(role: .destructive) {
                                        Task { await transferStore.delete(schedule: schedule) }
                                    } label: {
                                        Text("Delete")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(ModernTheme.tertiaryAccent)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
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
    @Environment(\.colorScheme) private var colorScheme

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
            ModernTheme.background(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if sourceAccount == nil || (executedIncomes.isEmpty && flowSteps.isEmpty) {
                        ContentUnavailableView(
                            "No Completed Transfers",
                            systemImage: "checkmark.seal",
                            description: Text("Run executions to see history here.")
                        )
                    } else {
                        incomeCard
                        allocationFlowCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: 600)
            }
        }
        .navigationTitle("Completed Transfers")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }

    private var incomeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Income into \(sourceAccountName)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.4), Color.green.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 70, height: 4)
                    .opacity(0.6)
            }

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.75), Color.green.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "banknote")
                            .foregroundStyle(.white)
                            .font(.headline)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(sourceAccountName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Total Executed Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("+\(formatCurrency(sourceIncomeTotal))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .glassCard()
    }

    private var allocationFlowCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Allocation Flow")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(annotatedSteps) { row in
                    let step = row.step

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(step.path)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                    if let tag = step.methodTag, !tag.isEmpty {
                                        Text(tag)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        tag == "BUDGET"
                                                        ? Color.gray.opacity(0.18)
                                                        : ModernTheme.secondaryAccent.opacity(0.18)
                                                    )
                                            )
                                            .foregroundStyle(
                                                tag == "BUDGET"
                                                ? .secondary
                                                : ModernTheme.secondaryAccent
                                            )
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
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(ModernTheme.tertiaryAccent.opacity(0.15))
                                )
                                .foregroundStyle(ModernTheme.tertiaryAccent)
                        }

                        HStack {
                            Text("Remaining in \(sourceAccountName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatCurrency(row.remainingAfter))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(ModernTheme.primaryAccent)
                        }
                        .padding(.horizontal, 8)
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

                // Final balance
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.primaryAccent.opacity(0.75), ModernTheme.secondaryAccent.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.white)
                                .font(.headline)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Final Balance in \(sourceAccountName)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text(formatCurrency(finalRemaining))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(ModernTheme.secondaryAccent)
                    }

                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .glassCard()
    }
}

#Preview {
    let accounts = AccountsStore()
    let transferStore = TransferSchedulesStore(accountsStore: accounts)
    return ManageTransferSchedulesView(isPresented: .constant(true))
        .environmentObject(accounts)
        .environmentObject(transferStore)
}
