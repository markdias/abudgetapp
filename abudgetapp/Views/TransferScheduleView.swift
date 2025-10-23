import SwiftUI

struct TransferScheduleView: View {
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @EnvironmentObject private var accountsStore: AccountsStore

    @State private var showingComposer = false
    @State private var groupingMode: GroupingMode = .destination

    enum GroupingMode: String, CaseIterable, Identifiable {
        case destination = "By Destination"
        case flat = "All"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                if groupingMode == .destination {
                    ForEach(transferStore.groupsByDestination()) { group in
                        Section(header: Text(group.title)) {
                            if let subtitle = group.subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                            ForEach(group.schedules) { schedule in
                                TransferScheduleRow(schedule: schedule, accountName: accountName(for: schedule)) {
                                    execute(schedule: schedule)
                                } deleteAction: {
                                    delete(schedule: schedule)
                                }
                            }
                        }
                    }
                } else {
                    Section("All Schedules") {
                        ForEach(transferStore.schedules) { schedule in
                            TransferScheduleRow(schedule: schedule, accountName: accountName(for: schedule)) {
                                execute(schedule: schedule)
                            } deleteAction: {
                                delete(schedule: schedule)
                            }
                        }
                    }
                }
            }
            .overlay {
                if transferStore.schedules.isEmpty {
                    ContentUnavailableView("No Transfer Schedules", systemImage: "arrow.left.arrow.right") {
                        Text("Create a transfer schedule to automate pot or account movements.")
                    }
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
                    Button("Execute All", action: executeAll)
                        .disabled(transferStore.schedules.isEmpty)
                    Button(action: { showingComposer = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await transferStore.load()
            }
            .sheet(isPresented: $showingComposer) {
                TransferComposerView(isPresented: $showingComposer)
            }
        }
    }

    private func accountName(for schedule: TransferSchedule) -> String {
        if let account = accountsStore.account(for: schedule.toAccountId) {
            return account.name
        }
        return "Account #\(schedule.toAccountId)"
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
}

private struct TransferScheduleRow: View {
    let schedule: TransferSchedule
    let accountName: String
    let executeAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.description)
                        .font(.headline)
                    Text("Destination: \(accountName)\(schedule.toPotName != nil ? " · \(schedule.toPotName!)" : "")")
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
                Button("Delete", role: .destructive, action: deleteAction)
                    .buttonStyle(.bordered)
                Spacer()
                if let last = schedule.lastExecuted {
                    Text("Last run: \(last)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
