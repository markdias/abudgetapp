import SwiftUI

struct TransfersView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeSchedulesStore: IncomeSchedulesStore
    @EnvironmentObject private var transferSchedulesStore: TransferSchedulesStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingIncomeSchedules = false
    @State private var showingTransferSchedules = false
    @State private var showingProcessedTransactions = false
    @State private var isResetting = false
    @State private var showingResetConfirm = false
    @State private var showingSalarySorter = false
    @State private var showingBalanceHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 18) {
                            LargeActionButton(title: "Income Schedules", icon: "calendar.badge.clock", gradient: [ModernTheme.secondaryAccent, Color(red: 0.39, green: 0.95, blue: 0.82)]) {
                                showingIncomeSchedules = true
                            }
                            LargeActionButton(title: "Transfer Schedules", icon: "arrow.left.arrow.right.circle.fill", gradient: [ModernTheme.primaryAccent, Color(red: 0.32, green: 0.72, blue: 1.0)]) { showingTransferSchedules = true }
                            LargeActionButton(title: "Processed Transactions", icon: "checklist.checked", gradient: [Color(red: 0.27, green: 0.85, blue: 0.96), ModernTheme.primaryAccent]) {
                                showingProcessedTransactions = true
                            }
                            LargeActionButton(title: "Salary Sorter", icon: "chart.pie.fill", gradient: [Color(red: 0.76, green: 0.38, blue: 0.98), ModernTheme.tertiaryAccent]) { showingSalarySorter = true }
                            LargeActionButton(title: "Balance Reduction", icon: "chart.line.downtrend.xyaxis", gradient: [Color(red: 0.19, green: 0.65, blue: 0.98), ModernTheme.secondaryAccent]) {
                                showingBalanceHistory = true
                            }
                            LargeActionButton(title: "Reset Balance", icon: "arrow.counterclockwise.circle.fill", gradient: [Color(red: 1.0, green: 0.44, blue: 0.56), Color(red: 1.0, green: 0.68, blue: 0.41)]) {
                                showingResetConfirm = true
                            }
                        }
                        .frame(maxWidth: 480)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Transfers")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .sheet(isPresented: $showingIncomeSchedules) {
                ManageIncomeSchedulesView(isPresented: $showingIncomeSchedules)
            }
            .sheet(isPresented: $showingTransferSchedules) {
                ManageTransferSchedulesView(isPresented: $showingTransferSchedules)
            }
            .sheet(isPresented: $showingSalarySorter) {
                SalarySorterView(isPresented: $showingSalarySorter)
            }
            .sheet(isPresented: $showingBalanceHistory) {
                BalanceReductionView(isPresented: $showingBalanceHistory)
            }
            .sheet(isPresented: $showingProcessedTransactions) {
                ProcessedTransactionsView()
            }
            .alert("Reset Balances?", isPresented: $showingResetConfirm) {
                Button("Reset", role: .destructive) {
                    Task {
                        guard !isResetting else { return }
                        isResetting = true
                        await accountsStore.resetBalances()
                        // Reload accounts to ensure all dependent views (e.g., Activities, Pots) refresh immediately
                        await accountsStore.loadAccounts()
                        await incomeSchedulesStore.load()
                        await transferSchedulesStore.load()
                        isResetting = false
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will set all non-excluded card and pot balances to 0 and re-enable all scheduled incomes for execution.")
            }
        }
    }
}

private struct LargeActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    gradient.first ?? ModernTheme.primaryAccent,
                                    gradient.last ?? ModernTheme.secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                        )
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                            colors: gradient.map { $0.opacity(0.85) } + [Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernTheme.cardCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.25 : 0.16), lineWidth: 0.8)
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 22, x: 0, y: 16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

struct BalanceReductionView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @State private var isReducing = false
    @AppStorage("autoReduceBalancesEnabled") private var autoReduceEnabled = false
    @State private var lastManualMessage: String?

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private struct RunGroup: Identifiable {
        let id: String
        let timestamp: String
        let entries: [BalanceReductionLog]

        var totalReduction: Double {
            entries.reduce(0) { $0 + max($1.reductionAmount, 0) }
        }

        var dayOfMonth: Int? {
            entries.first?.dayOfMonth
        }
    }

    private var groupedRuns: [RunGroup] {
        let grouped = Dictionary(grouping: accountsStore.balanceReductionLogs) { $0.timestamp }
        return grouped
            .map { RunGroup(id: $0.key, timestamp: $0.key, entries: $0.value.sorted { $0.accountName < $1.accountName }) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        reduceNowCard
                        reductionRunsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 600)
                }
            }
            .navigationTitle("Balance Reduction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { isPresented = false }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }

    private var reduceNowCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Reduce Balances")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.19, green: 0.65, blue: 0.98).opacity(0.4), ModernTheme.secondaryAccent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 70, height: 4)
                    .opacity(0.6)
            }

            Button {
                Task { await runManualReduction() }
            } label: {
                HStack(spacing: 6) {
                    if isReducing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text(isReducing ? "Reducing…" : "Reduce Now")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.19, green: 0.65, blue: 0.98), ModernTheme.secondaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(isReducing)
            .opacity(isReducing ? 0.6 : 1)

            Divider()
                .padding(.vertical, 4)

            Toggle(isOn: $autoReduceEnabled) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reduce on App Active")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Automatically reduces when app becomes active.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let summary = lastRunSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = lastManualMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.19, green: 0.65, blue: 0.98))
                }
            }
        }
        .glassCard()
    }

    private var reductionRunsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reduction History")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
            }

            if groupedRuns.isEmpty {
                ContentUnavailableView(
                    "No Reductions Logged",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Run the reduction workflow to see a breakdown of changes.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(groupedRuns) { run in
                        runRow(for: run)
                    }
                }
            }
        }
        .glassCard()
    }

    @ViewBuilder
    private func runRow(for run: RunGroup) -> some View {
        let total = run.totalReduction

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                total > 0 ? Color(red: 0.19, green: 0.65, blue: 0.98).opacity(0.75) : Color.gray.opacity(0.5),
                                total > 0 ? ModernTheme.secondaryAccent.opacity(0.5) : Color.gray.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: total > 0 ? "chart.line.downtrend.xyaxis" : "minus.circle")
                            .foregroundStyle(.white)
                            .font(.headline)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(formattedHeader(for: run))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(total > 0 ? "Reduced by \(formatCurrency(total))" : "No change")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(total > 0 ? Color(red: 0.19, green: 0.65, blue: 0.98) : .secondary)
                }

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(run.entries) { entry in
                    entryRow(for: entry)
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

    @ViewBuilder
    private func entryRow(for entry: BalanceReductionLog) -> some View {
        let reduction = max(entry.reductionAmount, 0)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.accountName)
                    .font(.caption.weight(.semibold))
                Text("\(formatCurrency(entry.baselineBalance)) → \(formatCurrency(entry.resultingBalance))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(reduction > 0 ? "-\(formatCurrency(reduction))" : "No change")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(reduction > 0 ? Color(red: 0.19, green: 0.65, blue: 0.98).opacity(0.18) : Color.gray.opacity(0.18))
                )
                .foregroundStyle(reduction > 0 ? Color(red: 0.19, green: 0.65, blue: 0.98) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func formattedHeader(for run: RunGroup) -> String {
        let datePart = formattedDate(for: run.timestamp)
        if let day = run.dayOfMonth {
            return "\(datePart) · Day \(day)"
        }
        return datePart
    }

    private func formattedDate(for timestamp: String) -> String {
        guard let date = BalanceReductionView.isoFormatter.date(from: timestamp) else {
            return timestamp
        }
        return BalanceReductionView.displayFormatter.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let number = NSNumber(value: value)
        return BalanceReductionView.currencyFormatter.string(from: number)
            ?? String(format: "£%.2f", value)
    }

    private var lastRunSummary: String? {
        guard let latest = groupedRuns.first else { return nil }
        let total = latest.totalReduction
        let date = formattedDate(for: latest.timestamp)
        if total > 0 {
            return "Last run on \(date) reduced balances by \(formatCurrency(total))."
        }
        return "Last run on \(date) made no balance changes."
    }

    @MainActor
    private func runManualReduction() async {
        guard !isReducing else { return }
        isReducing = true
        lastManualMessage = nil
        await accountsStore.applyMonthlyReduction()
        isReducing = false
        lastManualMessage = "Manual reduction completed."
    }
}

#Preview {
    TransfersView()
}
