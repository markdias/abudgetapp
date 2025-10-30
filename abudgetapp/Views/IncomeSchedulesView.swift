import SwiftUI

struct ManageIncomeSchedulesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        addIncomeCard
                        activeSchedulesCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 600)
                }
            }
            .navigationTitle("Income Schedules")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { isPresented = false } } }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .task { await incomeStore.load() }
        }
    }

    private var addIncomeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Add New Income Schedule")
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

            if accountsStore.accounts.flatMap({ $0.incomes ?? [] }).isEmpty {
                ContentUnavailableView(
                    "No incomes available",
                    systemImage: "tray",
                    description: Text("Log incomes against your accounts to create schedules.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(accountsStore.accounts) { account in
                        if let incomes = account.incomes, !incomes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(account.name)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                ForEach(incomes, id: \.id) { income in
                                    let alreadyScheduled = incomeStore.schedules.contains { $0.accountId == account.id && $0.incomeId == income.id }
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
                                                Image(systemName: "banknote")
                                                    .foregroundStyle(.white)
                                                    .font(.headline)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                                            )
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(income.description)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            Text("£\(String(format: "%.2f", income.amount)) — \(income.company)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if alreadyScheduled {
                                            Text("Scheduled")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(ModernTheme.secondaryAccent.opacity(0.18))
                                                )
                                                .foregroundStyle(ModernTheme.secondaryAccent)
                                        } else {
                                            Button("Schedule") {
                                                Task { await incomeStore.addSchedule(for: account.id, income: income) }
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
                            }
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private var activeSchedulesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Income Schedules")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Button {
                    Task { await incomeStore.executeAll() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                        Text("Execute All")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
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
                .disabled(incomeStore.schedules.allSatisfy { $0.isCompleted })
                .opacity(incomeStore.schedules.allSatisfy { $0.isCompleted } ? 0.6 : 1)
            }

            if incomeStore.schedules.isEmpty {
                ContentUnavailableView(
                    "No scheduled incomes",
                    systemImage: "calendar",
                    description: Text("Add an income schedule above to see it here.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(incomeStore.schedules) { schedule in
                        HStack(alignment: .top, spacing: 16) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            schedule.isCompleted ? Color.green.opacity(0.75) : ModernTheme.primaryAccent.opacity(0.75),
                                            schedule.isCompleted ? Color.green.opacity(0.35) : ModernTheme.secondaryAccent.opacity(0.45)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: schedule.isCompleted ? "checkmark.seal.fill" : "calendar.badge.clock")
                                        .foregroundStyle(.white)
                                        .font(.headline)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(schedule.description)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text(schedule.company)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("£\(String(format: "%.2f", schedule.amount))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(ModernTheme.secondaryAccent)
                                statusBadge(for: schedule)
                            }

                            Spacer()

                            VStack(spacing: 10) {
                                Button(schedule.isCompleted ? "Executed" : "Execute") {
                                    Task { await incomeStore.execute(schedule: schedule) }
                                }
                                .disabled(schedule.isCompleted)
                                .buttonStyle(.borderedProminent)
                                .tint(schedule.isCompleted ? .gray : ModernTheme.secondaryAccent)

                                Button(role: .destructive) {
                                    Task { await incomeStore.delete(schedule: schedule) }
                                } label: {
                                    Text("Delete")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(ModernTheme.tertiaryAccent)
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
        .glassCard()
    }

    private func statusBadge(for schedule: IncomeSchedule) -> some View {
        let isPending = !schedule.isCompleted
        let text = isPending ? "Pending" : "Completed"
        let colors: (Color, Color) = isPending
            ? (ModernTheme.primaryAccent.opacity(0.18), ModernTheme.primaryAccent)
            : (ModernTheme.secondaryAccent.opacity(0.22), ModernTheme.secondaryAccent)
        return Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(colors.0)
            )
            .foregroundStyle(colors.1)
    }
}

#Preview {
    let accounts = AccountsStore()
    let incomeStore = IncomeSchedulesStore(accountsStore: accounts)
    return ManageIncomeSchedulesView(isPresented: .constant(true))
        .environmentObject(accounts)
        .environmentObject(incomeStore)
}
