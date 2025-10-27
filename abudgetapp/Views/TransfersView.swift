import SwiftUI

struct TransfersView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeSchedulesStore: IncomeSchedulesStore
    @EnvironmentObject private var transferSchedulesStore: TransferSchedulesStore
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
                BrandBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Move money and stay on track")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(LinearGradient(colors: [BrandTheme.accent, BrandTheme.accentSecondary], startPoint: .leading, endPoint: .trailing))

                            VStack(spacing: 18) {
                                LargeActionButton(title: "Transfer Schedules", icon: "arrow.left.arrow.right", gradient: [BrandTheme.accentSecondary, Color.blue.opacity(0.7)]) { showingTransferSchedules = true }
                                LargeActionButton(title: "Income Schedules", icon: "calendar.badge.clock", gradient: [BrandTheme.accentTertiary, Color.green.opacity(0.7)]) {
                                    showingIncomeSchedules = true
                                }
                                LargeActionButton(title: "Processed Transactions", icon: "tray.full.fill", gradient: [BrandTheme.accentQuaternary, Color.teal.opacity(0.7)]) {
                                    showingProcessedTransactions = true
                                }
                                LargeActionButton(title: "Salary Sorter", icon: "chart.pie.fill", gradient: [BrandTheme.accent, Color.pink.opacity(0.7)]) { showingSalarySorter = true }
                                LargeActionButton(title: "Balance Reduction", icon: "chart.line.downtrend.xyaxis", gradient: [BrandTheme.accentTertiary, Color.mint.opacity(0.7)]) {
                                    showingBalanceHistory = true
                                }
                                LargeActionButton(title: "Reset Balance", icon: "arrow.counterclockwise", gradient: [BrandTheme.accentQuaternary, BrandTheme.accent]) {
                                    showingResetConfirm = true
                                }
                            }
                        }
                        .brandCardStyle()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Transfers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
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
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: gradient.first?.opacity(0.4) ?? BrandTheme.accent.opacity(0.3), radius: 10, x: 0, y: 6)

                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
        }
        .foregroundStyle(.primary)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .background(BlurView(style: .systemMaterialDark).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityAddTraits(.isButton)
    }
}

struct BalanceReductionView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
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
            List {
                Section {
                    Button {
                        Task { await runManualReduction() }
                    } label: {
                        HStack(spacing: 12) {
                            if isReducing {
                                ProgressView()
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                            Text(isReducing ? "Reducing…" : "Reduce Now")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isReducing)

                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            autoReduceEnabled
                                ? "Automatic reduction runs when the app becomes active."
                                : "Automatic reduction is off.",
                            systemImage: autoReduceEnabled ? "bolt.badge.clock" : "bolt.slash"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        if let summary = lastRunSummary {
                            Text(summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let message = lastManualMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundColor(.teal)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Reduction Runs") {
                    if groupedRuns.isEmpty {
                        ContentUnavailableView(
                            "No Reductions Logged",
                            systemImage: "chart.line.downtrend.xyaxis",
                            description: Text("Run the reduction workflow to see a breakdown of changes.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(groupedRuns) { run in
                            runRow(for: run)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Balance Reduction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private func runRow(for run: RunGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(formattedHeader(for: run))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                let total = run.totalReduction
                Text(total > 0 ? "-\(formatCurrency(total))" : "No change")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(total > 0 ? .teal : .secondary)
            }

            VStack(spacing: 8) {
                ForEach(run.entries) { entry in
                    entryRow(for: entry)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func entryRow(for entry: BalanceReductionLog) -> some View {
        let reduction = max(entry.reductionAmount, 0)

        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.accountName)
                    .font(.subheadline.weight(.semibold))
                Text("\(formatCurrency(entry.baselineBalance)) → \(formatCurrency(entry.resultingBalance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(reduction > 0 ? "-\(formatCurrency(reduction))" : "No change")
                .font(.caption.weight(.semibold))
                .foregroundStyle(reduction > 0 ? .teal : .secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
