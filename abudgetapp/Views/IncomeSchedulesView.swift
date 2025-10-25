import SwiftUI

struct ManageIncomeSchedulesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add New Income Schedule").font(.headline)
                    incomesGrid
                    Divider()
                    Button {
                        Task { await incomeStore.executeAll() }
                    } label: {
                        Text("Execute All Income Schedules")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(incomeStore.schedules.allSatisfy { $0.isCompleted })
                    Divider()
                    Text("Active Income Schedules").font(.headline)
                    schedulesList
                }
                .padding()
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Income Schedules")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } } }
            .task { await incomeStore.load() }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Incomes Grid
    private var incomesGrid: some View {
        let accounts = accountsStore.accounts
        return Group {
            if accounts.flatMap({ $0.incomes ?? [] }).isEmpty {
                Text("No incomes available").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(accounts) { account in
                        if let incomes = account.incomes, !incomes.isEmpty {
                            ForEach(incomes, id: \.id) { income in
                                let alreadyScheduled = incomeStore.schedules.contains { $0.accountId == account.id && $0.incomeId == income.id }
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(income.description)
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text("£\(String(format: "%.2f", income.amount)) - \(income.company)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if alreadyScheduled {
                                        Text("SCHEDULED")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.15))
                                            .foregroundColor(.secondary)
                                            .clipShape(Capsule())
                                    } else {
                                        Button("Schedule") { Task { await incomeStore.addSchedule(for: account.id, income: income) } }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.blue)
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
        }
    }

    // MARK: - Schedules List
    private var schedulesList: some View {
        Group {
            if incomeStore.schedules.isEmpty {
                Text("No scheduled incomes").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(incomeStore.schedules) { schedule in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(schedule.description)
                                    .font(.subheadline).fontWeight(.semibold)
                                Text(schedule.company)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Amount: £\(String(format: "%.2f", schedule.amount))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                statusBadge(for: schedule)
                            }
                            Spacer(minLength: 12)
                            VStack(spacing: 8) {
                                Button(schedule.isCompleted ? "Executed" : "Execute") {
                                    Task { await incomeStore.execute(schedule: schedule) }
                                }
                                .disabled(schedule.isCompleted)
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                Button(role: .destructive) { Task { await incomeStore.delete(schedule: schedule) } } label: { Text("Delete") }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
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

    private func statusBadge(for schedule: IncomeSchedule) -> some View {
        let isPending = !(schedule.isCompleted)
        let text = isPending ? "PENDING" : "COMPLETED"
        let bg: Color = isPending ? .blue.opacity(0.15) : .green.opacity(0.15)
        let fg: Color = isPending ? .blue : .green
        return Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .foregroundColor(fg)
            .clipShape(Capsule())
    }
}

#Preview {
    let accounts = AccountsStore()
    let incomeStore = IncomeSchedulesStore(accountsStore: accounts)
    return ManageIncomeSchedulesView(isPresented: .constant(true))
        .environmentObject(accounts)
        .environmentObject(incomeStore)
}
