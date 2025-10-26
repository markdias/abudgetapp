import SwiftUI

struct ProcessedTransactionsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    private var transactions: [TransactionRecord] {
        accountsStore.transactions.sorted { lhs, rhs in
            switch (lhs.processedDate, rhs.processedDate) {
            case let (left?, right?):
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.date > rhs.date
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    EmptyTransactionsState()
                } else {
                    List {
                        ForEach(transactions) { record in
                            ProcessedTransactionRow(record: record)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Processed Transactions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct ProcessedTransactionRow: View {
    let record: TransactionRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundColor(.green)
                .opacity(record.isProcessedScheduledPayment ? 1 : 0)
                .accessibilityLabel("Processed scheduled payment")
                .accessibilityHidden(!record.isProcessedScheduledPayment)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                if !record.vendor.isEmpty {
                    Text(record.vendor)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let potName = record.toPotName, !potName.isEmpty {
                    Text("Pot: \(potName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                if record.isProcessedScheduledPayment {
                    Text("Processed automatically")
                        .font(.footnote)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(record.amount >= 0 ? "-\(record.formattedAmount)" : record.formattedAmount)
                    .font(.headline)
                    .foregroundColor(record.amount >= 0 ? .red : .green)
                Text(record.formattedDate)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyTransactionsState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 42))
                .foregroundColor(.secondary)
            Text("No Transactions")
                .font(.headline)
            Text("Transactions will appear here after they are recorded or processed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ProcessedTransactionsView()
        .environmentObject(AccountsStore())
}
