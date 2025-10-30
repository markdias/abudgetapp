import SwiftUI

struct ProcessedTransactionsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @AppStorage("autoProcessTransactionsEnabled") private var autoProcessingEnabled = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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

        return accountsStore.transactions
            .filter { $0.kind == .scheduled }
            .compactMap { transaction in
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
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        processingCard
                        scheduledTransactionsCard
                        if !processedLogsThisPeriod.isEmpty {
                            processedLogsCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Processed Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }

    private var processingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Manual Processing")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.primaryAccent.opacity(0.45), ModernTheme.secondaryAccent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 64, height: 4)
                    .opacity(0.7)
            }

            Button {
                Task { await runManualProcess() }
            } label: {
                HStack(spacing: 12) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                    }
                    Text(isProcessing ? "Processing…" : "Process Transactions Now")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: ModernTheme.cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.primaryAccent, ModernTheme.secondaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.7 : 1)

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    autoProcessingEnabled ? "Automatic processing runs when the app opens." : "Automatic processing is off.",
                    systemImage: autoProcessingEnabled ? "bolt.badge.clock" : "bolt.slash"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let summary = summaryText {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
    }

    private var scheduledTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Scheduled Transactions")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.secondaryAccent.opacity(0.5), ModernTheme.primaryAccent.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 72, height: 4)
                    .opacity(0.7)
            }

            if scheduledItems.isEmpty {
                ContentUnavailableView(
                    "No Scheduled Transactions",
                    systemImage: "tray",
                    description: Text("Add transactions in Home → Add Transaction to see them here.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(scheduledItems) { item in
                        ScheduledItemRow(item: item)
                    }
                }
            }
        }
        .glassCard()
    }

    private var processedLogsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Processed This Month")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.tertiaryAccent.opacity(0.45), ModernTheme.primaryAccent.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 4)
                    .opacity(0.7)
            }

            VStack(spacing: 12) {
                ForEach(processedLogsThisPeriod) { log in
                    ProcessedLogRow(
                        log: log,
                        accountName: accountsStore.account(for: log.accountId)?.name ?? "Account #\(log.accountId)"
                    )
                }
            }
        }
        .glassCard()
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
        @Environment(\.colorScheme) private var colorScheme
        let item: ScheduledItem

        var body: some View {
            HStack(alignment: .center, spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: item.isProcessed
                                ? [ModernTheme.secondaryAccent, Color.green.opacity(0.55)]
                                : [ModernTheme.primaryAccent, ModernTheme.tertiaryAccent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: item.isProcessed ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                            .foregroundStyle(.white)
                            .font(.headline)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.transaction.name.isEmpty ? item.transaction.vendor : item.transaction.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(destinationLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    infoLine
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(currencyString(item.transaction.amount))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ModernTheme.secondaryAccent)
                    Text("Day \(item.scheduledDay)")
                        .font(.caption2)
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

        private var destinationLine: String {
            if let pot = item.potName, !pot.isEmpty {
                return "\(item.accountName) · \(pot)"
            }
            return item.accountName
        }

        @ViewBuilder
        private var infoLine: some View {
            if let processedAt = item.processedAt {
                Text(ProcessedTransactionsView.displayDateFormatter.string(from: processedAt))
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
        @Environment(\.colorScheme) private var colorScheme
        let log: ProcessedTransactionLog
        let accountName: String

        var body: some View {
            HStack(alignment: .center, spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: log.wasManual
                                ? [ModernTheme.tertiaryAccent, Color.orange.opacity(0.55)]
                                : [ModernTheme.secondaryAccent, Color.green.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: log.wasManual ? "hand.tap.fill" : "clock.fill")
                            .foregroundStyle(.white)
                            .font(.headline)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(log.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(destinationLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    infoStack
                }

                Spacer()

                Text(currencyString(log.amount))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(ModernTheme.secondaryAccent)
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
