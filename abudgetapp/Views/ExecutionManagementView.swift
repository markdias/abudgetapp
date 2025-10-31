import SwiftUI

struct ExecutionManagementView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeSchedulesStore: IncomeSchedulesStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var isDeletingRange = false
    @State private var isDeletingRun = false
    @State private var showRangeConfirm = false
    @State private var rangeValidationMessage: String?
    @State private var pendingRun: ExecutionRunGroup?
    @State private var showRunConfirm = false
    @State private var lastSummary: ExecutionPurgeSummary?
    @State private var lastActionDescription: String?
    @State private var expandedRuns: Set<String> = []

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

    private var runGroups: [ExecutionRunGroup] {
        var accumulator: [String: ExecutionRunAccumulator] = [:]

        for transaction in accountsStore.transactions {
            guard let events = transaction.events else { continue }
            for event in events {
                var entry = accumulator[event.executedAt] ?? ExecutionRunAccumulator()
                entry.date = entry.date ?? ExecutionManagementView.isoFormatter.date(from: event.executedAt)
                entry.transactionEvents += 1
                entry.transactionDetails.append(transactionDetail(for: transaction, event: event))
                accumulator[event.executedAt] = entry
            }
        }

        for schedule in incomeSchedulesStore.schedules {
            guard let events = schedule.events else { continue }
            for event in events {
                var entry = accumulator[event.executedAt] ?? ExecutionRunAccumulator()
                entry.date = entry.date ?? ExecutionManagementView.isoFormatter.date(from: event.executedAt)
                entry.incomeEvents += 1
                entry.incomeDetails.append(incomeDetail(for: schedule, event: event))
                accumulator[event.executedAt] = entry
            }
        }

        for log in accountsStore.processedTransactionLogs {
            var entry = accumulator[log.processedAt] ?? ExecutionRunAccumulator()
            entry.date = entry.date ?? ExecutionManagementView.isoFormatter.date(from: log.processedAt)
            entry.processedLogs += 1
            entry.processedLogDetails.append(processedLogDetail(for: log))
            accumulator[log.processedAt] = entry
        }

        return accumulator
            .map { timestamp, entry in
                ExecutionRunGroup(
                    timestamp: timestamp,
                    date: entry.date,
                    transactionEvents: entry.transactionEvents,
                    incomeEvents: entry.incomeEvents,
                    logCount: entry.processedLogs,
                    transactionDetails: entry.transactionDetails,
                    incomeDetails: entry.incomeDetails,
                    logDetails: entry.processedLogDetails
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.date, rhs.date) {
                case let (lhsDate?, rhsDate?):
                    return lhsDate > rhsDate
                case (nil, nil):
                    return lhs.timestamp > rhs.timestamp
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                }
            }
    }

    private var lastSummaryText: String? {
        guard let summary = lastSummary else { return nil }
        var parts: [String] = []
        let executionsRemoved = summary.totalExecutionsRemoved
        let logsRemoved = summary.processedLogsRemoved
        if executionsRemoved > 0 {
            parts.append("\(executionsRemoved) execution\(executionsRemoved == 1 ? "" : "s") removed")
        }
        if logsRemoved > 0 {
            parts.append("\(logsRemoved) log\(logsRemoved == 1 ? "" : "s") cleared")
        }
        if summary.totalRunsAffected > 0 {
            parts.append("across \(summary.totalRunsAffected) run\(summary.totalRunsAffected == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            parts.append("No executions matched the selected criteria.")
        }
        if let action = lastActionDescription {
            parts.insert(action, at: 0)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        rangeCard
                        runsCard
                        if let summaryText = lastSummaryText {
                            summaryCard(summaryText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Execution Management")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .alert("Delete Executions?", isPresented: $showRangeConfirm) {
                Button("Delete", role: .destructive) {
                    Task { await performRangeDeletion() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let formattedStart = formatted(date: Calendar.current.startOfDay(for: startDate))
                let formattedEnd = formatted(date: Calendar.current.startOfDay(for: endDate))
                Text("Remove all executions and logs captured between \(formattedStart) and \(formattedEnd). This cannot be undone.")
            }
            .alert("Delete Run?", isPresented: $showRunConfirm) {
                Button("Delete", role: .destructive) {
                    if let run = pendingRun {
                        Task { await performRunDeletion(run) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingRun = nil
                }
            } message: {
                runAlertMessage()
            }
        }
    }

    private var rangeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader(title: "Date Range Cleanup")
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
            }
            if let message = rangeValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button {
                validateAndConfirmRange()
            } label: {
                HStack(spacing: 10) {
                    if isDeletingRange {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                            .font(.headline)
                    }
                    Text(isDeletingRange ? "Deleting…" : "Delete Executions in Range")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                        .fill(Color.red.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .foregroundColor(isDeletingRange ? Color.secondary : Color.red)
            .disabled(isDeletingRange)
        }
        .glassCard()
    }

    private var runsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader(title: "Execution Runs")
            if runGroups.isEmpty {
                ContentUnavailableView(
                    "No Execution Runs",
                    systemImage: "tray",
                    description: Text("Run diagnostics or execute schedules to see history here.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(runGroups) { group in
                        DisclosureGroup(isExpanded: binding(for: group)) {
                            VStack(alignment: .leading, spacing: 16) {
                                runDetailSections(for: group)

                                Button {
                                    pendingRun = group
                                    showRunConfirm = true
                                } label: {
                                    Label("Delete Run", systemImage: "trash")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                                .fill(Color.red.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                                .disabled(isDeletingRun)
                                .opacity(isDeletingRun ? 0.7 : 1)
                            }
                            .padding(.top, 10)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatted(timestamp: group.timestamp))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text(group.detailLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

    private func summaryCard(_ summaryText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Action")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(summaryText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private func cardHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Spacer()
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [ModernTheme.secondaryAccent.opacity(0.45), ModernTheme.primaryAccent.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 70, height: 4)
                .opacity(0.7)
        }
    }

    private func formatted(timestamp: String) -> String {
        if let date = ExecutionManagementView.isoFormatter.date(from: timestamp) {
            return ExecutionManagementView.displayFormatter.string(from: date)
        }
        return timestamp
    }

    private func formatted(date: Date) -> String {
        ExecutionManagementView.displayFormatter.string(from: date)
    }

    private func validateAndConfirmRange() {
        rangeValidationMessage = nil
        guard startDate <= endDate else {
            rangeValidationMessage = "Start date must be before end date."
            return
        }
        showRangeConfirm = true
    }

    private func performRangeDeletion() async {
        guard !isDeletingRange else { return }
        isDeletingRange = true
        defer { isDeletingRange = false }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDayBase = calendar.startOfDay(for: endDate)
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endOfDayBase) ?? endOfDayBase

        let summary = await accountsStore.purgeExecutions(startDate: startOfDay, endDate: endOfDay)
        await incomeSchedulesStore.load()

        await MainActor.run {
            lastSummary = summary
            lastActionDescription = "Range cleanup completed"
        }
    }

    private func performRunDeletion(_ run: ExecutionRunGroup) async {
        guard !isDeletingRun else { return }
        isDeletingRun = true
        defer {
            isDeletingRun = false
            pendingRun = nil
        }

        let summary = await accountsStore.purgeExecutionRun(timestamp: run.timestamp)
        await incomeSchedulesStore.load()

        await MainActor.run {
            lastSummary = summary
            lastActionDescription = "Run deleted"
        }
    }

    private func runAlertMessage() -> Text {
        if let run = pendingRun {
            return Text("Remove all execution history recorded on \(formatted(timestamp: run.timestamp)). This cannot be undone.")
        }
        return Text("This cannot be undone.")
    }

    private func binding(for group: ExecutionRunGroup) -> Binding<Bool> {
        Binding(
            get: { expandedRuns.contains(group.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedRuns.insert(group.id)
                } else {
                    expandedRuns.remove(group.id)
                }
            }
        )
    }

    @ViewBuilder
    private func runDetailSections(for group: ExecutionRunGroup) -> some View {
        let hasTransactions = !group.transactionDetails.isEmpty
        let hasIncomes = !group.incomeDetails.isEmpty
        let hasLogs = !group.logDetails.isEmpty

        if hasTransactions {
            detailSection("Transactions", details: group.transactionDetails)
        }
        if hasIncomes {
            detailSection("Income Schedules", details: group.incomeDetails)
        }
        if hasLogs {
            detailSection("Processed Logs", details: group.logDetails)
        }
        if !hasTransactions && !hasIncomes && !hasLogs {
            Text("No execution details recorded for this run.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func detailSection(_ title: String, details: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(details.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    private func transactionDetail(for transaction: TransactionRecord, event: TransactionEvent) -> String {
        var components: [String] = []
        let name = transaction.name.isEmpty ? "Transaction #\(transaction.id)" : transaction.name
        components.append(name)
        components.append(formatAmount(event.amount))
        if !transaction.vendor.isEmpty {
            components.append("Vendor: \(transaction.vendor)")
        }
        if let destination = accountName(for: transaction.toAccountId) {
            components.append("To: \(destination)")
        }
        if let pot = transaction.toPotName, !pot.isEmpty {
            components.append("Pot: \(pot)")
        }
        components.append("Type: \(transactionTypeDescription(transaction))")
        return components.joined(separator: " • ")
    }

    private func incomeDetail(for schedule: IncomeSchedule, event: TransactionEvent) -> String {
        var components: [String] = []
        let name = schedule.description.isEmpty ? "Income #\(schedule.id)" : schedule.description
        components.append(name)
        components.append(formatAmount(event.amount))
        if !schedule.company.isEmpty {
            components.append("Company: \(schedule.company)")
        }
        if let account = accountName(for: schedule.accountId) {
            components.append("Account: \(account)")
        }
        return components.joined(separator: " • ")
    }

    private func processedLogDetail(for log: ProcessedTransactionLog) -> String {
        var components: [String] = []
        let name = log.name.isEmpty ? "Payment #\(log.paymentId)" : log.name
        components.append(name)
        components.append(formatAmount(log.amount))
        if !log.company.isEmpty {
            components.append("Company: \(log.company)")
        }
        if let account = accountName(for: log.accountId) {
            components.append("Account: \(account)")
        }
        if log.day > 0 {
            components.append("Day: \(log.day)")
        }
        return components.joined(separator: " • ")
    }

    private func formatAmount(_ value: Double) -> String {
        "£" + String(format: "%.2f", value)
    }

    private func accountName(for id: Int) -> String? {
        accountsStore.accounts.first(where: { $0.id == id })?.name
    }

    private func transactionTypeDescription(_ transaction: TransactionRecord) -> String {
        switch transaction.kind {
        case .scheduled:
            return "Scheduled"
        case .creditCardCharge:
            return "Credit Card Charge"
        case .creditCardPayment:
            return "Credit Card Payment"
        case .yearly:
            return "Yearly"
        }
    }
}

private struct ExecutionRunAccumulator {
    var date: Date?
    var transactionEvents: Int = 0
    var incomeEvents: Int = 0
    var processedLogs: Int = 0
    var transactionDetails: [String] = []
    var incomeDetails: [String] = []
    var processedLogDetails: [String] = []
}

private struct ExecutionRunGroup: Identifiable, Hashable {
    let timestamp: String
    let date: Date?
    let transactionEvents: Int
    let incomeEvents: Int
    let logCount: Int
    let transactionDetails: [String]
    let incomeDetails: [String]
    let logDetails: [String]

    var id: String { timestamp }

    var detailLine: String {
        var components: [String] = []
        let totalExecutions = transactionEvents + incomeEvents
        if totalExecutions > 0 {
            components.append("\(totalExecutions) execution\(totalExecutions == 1 ? "" : "s")")
        }
        if logCount > 0 {
            components.append("\(logCount) log\(logCount == 1 ? "" : "s")")
        }
        if components.isEmpty {
            components.append("No records")
        }
        return components.joined(separator: " • ")
    }
}
