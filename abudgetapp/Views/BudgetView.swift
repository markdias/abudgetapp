import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore

    private var budgetItems: [BudgetItem] {
        var items: [BudgetItem] = []
        for account in accountsStore.accounts {
            guard let pots = account.pots else { continue }
            for pot in pots {
                let allocated = pot.scheduled_payments?.reduce(0) { $0 + $1.amount } ?? 0
                items.append(
                    BudgetItem(
                        category: determineCategory(from: pot.name),
                        allocated: allocated,
                        spent: pot.balance
                    )
                )
            }
        }
        return items
    }

    private var totalAllocated: Double { budgetItems.reduce(0) { $0 + $1.allocated } }
    private var totalSpent: Double { budgetItems.reduce(0) { $0 + $1.spent } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BudgetSummaryCard(totalAllocated: totalAllocated, totalSpent: totalSpent)

                    if budgetItems.isEmpty {
                        ContentUnavailableView(
                            "No Budget Data",
                            systemImage: "chart.bar",
                            description: Text("Create pots and scheduled payments to see budget allocations.")
                        )
                    } else {
                        ForEach(budgetItems) { item in
                            BudgetItemRow(budgetItem: item)
                        }
                    }

                    Section("Upcoming Payments") {
                        ForEach(scheduledPaymentsStore.items.prefix(10)) { context in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(context.payment.name)
                                    Text("\(context.accountName)\(context.potName != nil ? " · \(context.potName!)" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("£\(String(format: "%.2f", context.payment.amount))")
                                    .foregroundColor(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Budget")
        }
    }

    private func determineCategory(from name: String) -> Category {
        let lowercased = name.lowercased()
        if lowercased.contains("bill") { return .utilities }
        if lowercased.contains("food") { return .food }
        if lowercased.contains("travel") || lowercased.contains("transport") { return .transport }
        if lowercased.contains("entertainment") || lowercased.contains("fun") { return .entertainment }
        if lowercased.contains("health") { return .health }
        if lowercased.contains("shop") { return .shopping }
        return .other
    }
}

private struct BudgetSummaryCard: View {
    let totalAllocated: Double
    let totalSpent: Double

    private var remaining: Double { totalAllocated - totalSpent }
    private var percentUsed: Double { totalAllocated > 0 ? min(totalSpent / totalAllocated, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Budget")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("£\(String(format: "%.2f", totalAllocated))")
                .font(.title2.bold())
            HStack {
                Text("Spent: £\(String(format: "%.2f", totalSpent))")
                Spacer()
                Text("Remaining: £\(String(format: "%.2f", remaining))")
                    .foregroundColor(remaining >= 0 ? .green : .red)
            }
            ProgressView(value: percentUsed)
                .tint(percentUsed < 0.7 ? .green : (percentUsed < 0.9 ? .yellow : .red))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct BudgetItemRow: View {
    let budgetItem: BudgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: budgetItem.category.icon)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading) {
                    Text(budgetItem.category.rawValue)
                        .font(.headline)
                    Text("Allocated £\(String(format: "%.2f", budgetItem.allocated))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Spent £\(String(format: "%.2f", budgetItem.spent))")
                    Text("Remaining £\(String(format: "%.2f", budgetItem.remaining))")
                        .foregroundColor(budgetItem.remaining >= 0 ? .green : .red)
                        .font(.caption)
                }
            }
            ProgressView(value: budgetItem.percentUsed)
                .tint(budgetItem.percentUsed < 0.7 ? .green : (budgetItem.percentUsed < 0.9 ? .yellow : .red))
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    BudgetView()
        .environmentObject(AccountsStore())
        .environmentObject(ScheduledPaymentsStore(accountsStore: AccountsStore()))
}
