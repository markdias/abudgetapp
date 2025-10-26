import SwiftUI

struct ProcessedTransactionsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @AppStorage("autoProcessTransactionsEnabled") private var autoProcessingEnabled = false
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var lastResult: ProcessTransactionsResult?

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let periodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func dayValue(from raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (1...31).contains(value) else { return nil }
        return value
    }

    private var currentPeriod: String {
        ProcessedTransactionsView.periodFormatter.string(from: Date())
    }

    private var processedLogsThisPeriod: [ProcessedTransactionLog] {
        accountsStore.processedTransactionLogs
            .filter { $0.period == currentPeriod }
            .sorted { $0.processedAt > $1.processedAt }
    }

    private var logsLookup: [Int: ProcessedTransactionLog] {
        var lookup: [Int: ProcessedTransactionLog] = [:]
        for log in processedLogsThisPeriod {
            lookup[log.paymentId] = log
        }
        return lookup
    }

    private var scheduledItems: [ScheduledItem] {
        let accountsById = Dictionary(uniqueKeysWithValues: accountsStore.accounts.map { ($0.id, $0) })
        let lookup = logsLookup

        return accountsStore.transactions.compactMap { transaction in
            guard let day = ProcessedTransactionsView.dayValue(from: transaction.date),
                  let account = accountsById[transaction.toAccountId] else {
                return nil
            }
            let log = lookup[transaction.id]
            let processedAt = log.flatMap { ProcessedTransactionsView.isoFormatter.date(from: $0.processedAt) }
            return ScheduledItem(
                transaction: transaction,
                accountName: account.name,
                potName: transaction.toPotName,
                scheduledDay: day,
                processedAt: processedAt,
                log: log
            )
        }
        .sorted {
            if $0.scheduledDay == $1.scheduledDay {
                return $0.transaction.name < $1.transaction.name
            }
            return $0.scheduledDay < $1.scheduledDay
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await runManualProcess() }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                            Text(isProcessing ? "Processing…" : "Process Transactions Now")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isProcessing)

                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            autoProcessingEnabled ? "Automatic processing runs when the app opens." : "Automatic processing is off.",
                            systemImage: autoProcessingEnabled ? "bolt.badge.clock" : "bolt.slash"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        if let summary = summaryText {
                            Text(summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Scheduled Transactions") {
                    if scheduledItems.isEmpty {
                        ContentUnavailableView(
                            "No Scheduled Transactions",
                            systemImage: "tray",
                            description: Text("Add transactions in Home → Add Transaction to see them here.")
                        )
                    } else {
                        ForEach(scheduledItems) { item in
                            ScheduledItemRow(item: item)
                        }
                    }
                }

                if !processedLogsThisPeriod.isEmpty {
                    Section("Processed This Month") {
                        ForEach(processedLogsThisPeriod) { log in
                            ProcessedLogRow(
                                log: log,
                                accountName: accountsStore.account(for: log.accountId)?.name ?? "Account #\(log.accountId)"
                            )
                        }
                    }
                }
            }
            .navigationTitle("Processed Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var summaryText: String? {
        guard let result = lastResult else { return nil }
        if let reason = result.blockedReason {
            return reason
        }
        if !result.processed.isEmpty {
            return "Processed \(result.processed.count) transaction(s)."
        }
        return "No scheduled transactions were due."
    }

    @MainActor
    private func runManualProcess() async {
        guard !isProcessing else { return }
        isProcessing = true
        let result = await accountsStore.processScheduledTransactions(forceManual: true)
        lastResult = result
        isProcessing = false
    }

    private struct ScheduledItem: Identifiable {
        let transaction: TransactionRecord
        let accountName: String
        let potName: String?
        let scheduledDay: Int
        let processedAt: Date?
        let log: ProcessedTransactionLog?

        var id: Int { transaction.id }
        var isProcessed: Bool { log != nil }
        var wasManual: Bool { log?.wasManual ?? false }
    }

    private struct ScheduledItemRow: View {
        let item: ScheduledItem

        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: item.isProcessed ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isProcessed ? .green : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.transaction.name)
                        .font(.headline)
                    Text(destinationLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    infoLine
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyString(item.transaction.amount))
                        .font(.headline)
                    Text("Day \(item.scheduledDay)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }

        private var destinationLine: String {
            if let pot = item.potName, !pot.isEmpty {
                return "\(item.accountName) · \(pot)"
            }
            return item.accountName
        }

        @ViewBuilder
        private var infoLine: some View {
            if let processedAt = item.processedAt {
                Text("Processed \(ProcessedTransactionsView.displayDateFormatter.string(from: processedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let vendorLine = vendorLabel {
                Text(vendorLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(item.isProcessed ? "Processed" : "Awaiting processing")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        private var vendorLabel: String? {
            guard !item.transaction.vendor.isEmpty else { return nil }
            if let type = item.transaction.paymentType {
                let paymentLabel: String
                switch type.lowercased() {
                case "direct_debit": paymentLabel = "Direct Debit"
                case "card": paymentLabel = "Card"
                default: paymentLabel = type.capitalized
                }
                return "\(item.transaction.vendor) · \(paymentLabel)"
            }
            return item.transaction.vendor
        }

        private func currencyString(_ amount: Double) -> String {
            "£" + String(format: "%.2f", amount)
        }
    }

    private struct ProcessedLogRow: View {
        let log: ProcessedTransactionLog
        let accountName: String

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.name)
                        .font(.headline)
                    Text(destinationLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    infoStack
                }
                Spacer()
                Text(currencyString(log.amount))
                    .font(.headline)
            }
            .padding(.vertical, 4)
        }

        private var destinationLine: String {
            if let potName = log.potName, !potName.isEmpty {
                return "\(accountName) · \(potName)"
            }
            return accountName
        }

        @ViewBuilder
        private var infoStack: some View {
            if let date = ProcessedTransactionsView.isoFormatter.date(from: log.processedAt) {
                Text(ProcessedTransactionsView.displayDateFormatter.string(from: date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if log.wasManual {
                Label("Manual run", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        private func currencyString(_ amount: Double) -> String {
            "£" + String(format: "%.2f", amount)
        }
    }
}

#Preview {
    let accounts = AccountsStore()
    return ProcessedTransactionsView()
        .environmentObject(accounts)
}
