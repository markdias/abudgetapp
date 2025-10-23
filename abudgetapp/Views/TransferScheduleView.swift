import SwiftUI

struct TransferScheduleView: View {
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore

    @State private var showingComposer = false
    @State private var editingSchedule: TransferSchedule? = nil
    @State private var groupingMode: GroupingMode = .destination

    enum GroupingMode: String, CaseIterable, Identifiable {
        case destination = "By Destination"
        case flat = "All"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                // Step 1: Execute incomes
                if !incomeStore.schedules.isEmpty {
                    Section(header: Text("Income to Execute")) {
                        ForEach(incomeStore.schedules) { schedule in
                            IncomeScheduleRow(schedule: schedule, accountName: accountName(forAccountId: schedule.accountId)) {
                                Task { await incomeStore.execute(scheduleId: schedule.id) }
                            }
                        }
                    }
                }
                if groupingMode == .destination {
                    ForEach(transferStore.groupsByDestination()) { group in
                        Section(header: Text(group.title)) {
                            if let subtitle = group.subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                            ForEach(group.schedules) { schedule in
                                TransferScheduleRow(
                                    schedule: schedule,
                                    fromLabel: fromLabel(for: schedule),
                                    toLabel: toLabel(for: schedule),
                                    canExecute: canExecute(schedule),
                                    ranSinceReset: ranSinceReset(schedule)
                                ) {
                                    execute(schedule: schedule)
                                } deleteAction: {
                                    delete(schedule: schedule)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button { editingSchedule = schedule } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                                }
                            }
                        }
                    }
                } else {
                    Section("All Schedules") {
                        ForEach(transferStore.schedules) { schedule in
                            TransferScheduleRow(
                                schedule: schedule,
                                fromLabel: fromLabel(for: schedule),
                                toLabel: toLabel(for: schedule),
                                canExecute: canExecute(schedule),
                                ranSinceReset: ranSinceReset(schedule)
                            ) {
                                execute(schedule: schedule)
                            } deleteAction: {
                                delete(schedule: schedule)
                            }
                            .swipeActions(edge: .trailing) {
                                Button { editingSchedule = schedule } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                            }
                        }
                    }
                }
            }
            .overlay {
                if transferStore.schedules.isEmpty {
                    ContentUnavailableView(
                        "No Transfer Schedules",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("Create a transfer schedule to automate pot or account movements.")
                    )
                }
            }
            .navigationTitle("Transfers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Grouping", selection: $groupingMode) {
                        ForEach(GroupingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !incomeStore.schedules.isEmpty {
                        Button("Execute Income") { Task { await incomeStore.executeAll() } }
                    }
                    Button("Execute All", action: executeAll)
                        .disabled(transferStore.schedules.isEmpty)
                    Button(action: { showingComposer = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await transferStore.load()
                await incomeStore.load()
            }
            .sheet(isPresented: $showingComposer) {
                TransferComposerView(isPresented: $showingComposer)
            }
            .sheet(item: $editingSchedule) { schedule in
                TransferEditorSheet(schedule: schedule)
            }
        }
    }

    private func accountName(forAccountId id: Int) -> String {
        accountsStore.account(for: id)?.name ?? "Account #\(id)"
    }

    private func execute(schedule: TransferSchedule) {
        Task { await transferStore.execute(scheduleId: schedule.id) }
    }

    private func executeAll() {
        Task { await transferStore.executeAll() }
    }

    private func delete(schedule: TransferSchedule) {
        Task { await transferStore.delete(scheduleId: schedule.id) }
    }
    private func canExecute(_ schedule: TransferSchedule) -> Bool {
        if let fromAccountId = schedule.fromAccountId, let account = accountsStore.account(for: fromAccountId) {
            if let potName = schedule.fromPotId, !potName.isEmpty, let pot = account.pots?.first(where: { $0.name == potName }) {
                return pot.balance >= schedule.amount
            }
            return account.balance >= schedule.amount
        }
        if let potName = schedule.fromPotId, !potName.isEmpty {
            if let dstAccount = accountsStore.account(for: schedule.toAccountId), let pot = dstAccount.pots?.first(where: { $0.name == potName }) {
                return pot.balance >= schedule.amount
            }
            for account in accountsStore.accounts {
                if let pot = account.pots?.first(where: { $0.name == potName }) {
                    return pot.balance >= schedule.amount
                }
            }
        }
        // No source specified, assume executable
        return true
    }

    private func ranSinceReset(_ schedule: TransferSchedule) -> Bool? {
        guard let lastReset = transferStore.lastResetAt else { return nil }
        guard let executed = schedule.lastExecuted else { return false }
        let iso = ISO8601DateFormatter()
        guard let resetDate = iso.date(from: lastReset), let execDate = iso.date(from: executed) else { return nil }
        return execDate >= resetDate
    }

    private func fromLabel(for schedule: TransferSchedule) -> String {
        var from = "From: "
        if let id = schedule.fromAccountId, let account = accountsStore.account(for: id) {
            from += account.name
            if let pot = schedule.fromPotId, !pot.isEmpty {
                from += " · \(pot)"
            }
        } else if let pot = schedule.fromPotId, !pot.isEmpty {
            from += pot
        } else {
            from += "—"
        }
        return from
    }

    private func toLabel(for schedule: TransferSchedule) -> String {
        var to = "To: "
        if let account = accountsStore.account(for: schedule.toAccountId) {
            to += account.name
        } else {
            to += "Account #\(schedule.toAccountId)"
        }
        if let pot = schedule.toPotName, !pot.isEmpty {
            to += " · \(pot)"
        } else {
            to += " · Main Account"
        }
        return to
    }
}

// MARK: - Transfer Editor

private struct TransferEditorSheet: View {
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    let schedule: TransferSchedule

    @State private var description: String = ""
    @State private var amount: String = ""
    @State private var toAccountId: Int
    @State private var toPotName: String = ""
    @State private var destinationKind: TransferDestinationKind

    init(schedule: TransferSchedule) {
        self.schedule = schedule
        _toAccountId = State(initialValue: schedule.toAccountId)
        _destinationKind = State(initialValue: schedule.destinationKind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Destination"), footer: Text(destinationKind.helperDescription)) {
                    Picker("Account", selection: $toAccountId) {
                        ForEach(accountsStore.accounts) { acc in
                            Text(acc.name).tag(acc.id)
                        }
                    }
                    Picker("Type", selection: $destinationKind) {
                        ForEach(TransferDestinationKind.allCases, id: \.self) { kind in
                            Text(kind.displayLabel).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    if destinationKind == .pot {
                        if let pots = accountsStore.account(for: toAccountId)?.pots, !pots.isEmpty {
                            Picker("Pot", selection: $toPotName) {
                                Text("Select Pot").tag("")
                                ForEach(pots, id: \.name) { pot in
                                    Text(pot.name).tag(pot.name)
                                }
                            }
                        } else {
                            Text("No pots available for this account")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section(header: Text("Details")) {
                    TextField("Description", text: $description)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Transfer")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .onAppear {
                description = schedule.description
                amount = String(format: "%.2f", schedule.amount)
                toPotName = schedule.toPotName ?? ""
            }
            .onChange(of: destinationKind) { newValue in
                if newValue == .account {
                    toPotName = ""
                } else if let pots = accountsStore.account(for: toAccountId)?.pots, let first = pots.first {
                    toPotName = first.name
                }
            }
            .onChange(of: toAccountId) { newValue in
                guard destinationKind == .pot else { return }
                if let pots = accountsStore.account(for: newValue)?.pots, pots.isEmpty {
                    destinationKind = .account
                }
            }
        }
    }

    private var canSave: Bool {
        guard Double(amount) != nil, !description.isEmpty else { return false }
        if destinationKind == .pot {
            return !(toPotName.isEmpty)
        }
        return true
    }

    private func save() async {
        guard let money = Double(amount) else { return }
        let submission = TransferScheduleSubmission(
            fromAccountId: schedule.fromAccountId,
            fromPotId: schedule.fromPotId,
            toAccountId: toAccountId,
            toPotName: destinationKind == .pot ? (toPotName.isEmpty ? nil : toPotName) : nil,
            amount: money,
            description: description,
            items: schedule.items,
            isDirectPotTransfer: schedule.isDirectPotTransfer
        )
        await transferStore.update(id: schedule.id, submission: submission)
        dismiss()
    }
}

private struct TransferScheduleRow: View {
    let schedule: TransferSchedule
    let fromLabel: String
    let toLabel: String
    var canExecute: Bool = true
    var ranSinceReset: Bool? = nil
    let executeAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.description)
                        .font(.headline)
                    Label(schedule.destinationKind == .account ? "Expense" : "Transfer", systemImage: schedule.destinationKind == .account ? "arrowshape.turn.up.left" : "arrow.left.arrow.right")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundColor(.white)
                        .background(schedule.destinationKind == .account ? Color.orange : Color.blue)
                        .clipShape(Capsule())
                        .accessibilityLabel(schedule.destinationKind.displayLabel)
                    Text(fromLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(toLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("£\(String(format: "%.2f", schedule.amount))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            if let items = schedule.items, !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(items, id: \.description) { item in
                        HStack {
                            Text(item.description)
                            Spacer()
                            Text("£\(String(format: "%.2f", item.amount))")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }

            HStack {
                Button("Execute", action: executeAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canExecute || schedule.isCompleted)
                Button("Delete", role: .destructive, action: deleteAction)
                    .buttonStyle(.bordered)
                Spacer()
                if schedule.isCompleted {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if let ran = ranSinceReset {
                    Text(ran ? "Ran since reset" : "Not run since reset")
                        .font(.caption2)
                        .foregroundStyle(ran ? .green : .orange)
                }
                if !canExecute {
                    Text("Insufficient funds")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                // Indicator will be filled by parent using environment; leave placeholder here
            }
        }
        .padding(.vertical, 8)
    }
}


private struct IncomeScheduleRow: View {
    let schedule: IncomeSchedule
    let accountName: String
    let executeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.description)
                        .font(.headline)
                    Text("Account: \(accountName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("£\(String(format: "%.2f", schedule.amount))")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            HStack {
                Button("Execute", action: executeAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(schedule.isCompleted)
                Spacer()
                if schedule.isCompleted {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    TransferScheduleView()
        .environmentObject(TransferSchedulesStore(accountsStore: AccountsStore()))
        .environmentObject(AccountsStore())
        .environmentObject(PotsStore(accountsStore: AccountsStore()))
}
