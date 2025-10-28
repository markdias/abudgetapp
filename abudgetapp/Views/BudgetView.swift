import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore
    @Environment(\.colorScheme) private var colorScheme

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
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        BudgetSummaryCard(totalAllocated: totalAllocated, totalSpent: totalSpent)

                        if budgetItems.isEmpty {
                            ContentUnavailableView(
                                "No Budget Data",
                                systemImage: "chart.bar",
                                description: Text("Create pots and scheduled payments to see budget allocations.")
                            )
                            .glassCard()
                        } else {
                            VStack(spacing: 16) {
                                ForEach(budgetItems) { item in
                                    BudgetItemRow(budgetItem: item)
                                }
                            }
                        }

                        if !scheduledPaymentsStore.items.isEmpty {
                            UpcomingPaymentsSection(items: Array(scheduledPaymentsStore.items.prefix(10)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Budget")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
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
    @Environment(\.colorScheme) private var colorScheme
    let totalAllocated: Double
    let totalSpent: Double

    private var remaining: Double { totalAllocated - totalSpent }
    private var percentUsed: Double { totalAllocated > 0 ? min(totalSpent / totalAllocated, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Monthly Budget")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.primaryAccent.opacity(0.5), ModernTheme.secondaryAccent.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 72, height: 4)
                    .opacity(0.7)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Allocated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("£\(String(format: "%.2f", totalAllocated))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ModernTheme.primaryAccent, ModernTheme.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            VStack(spacing: 8) {
                HStack {
                    Label("Spent", systemImage: "arrow.up.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("£\(String(format: "%.2f", totalSpent))")
                        .font(.headline)
                }

                HStack {
                    Label("Remaining", systemImage: "star.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("£\(String(format: "%.2f", remaining))")
                        .font(.headline)
                        .foregroundColor(remaining >= 0 ? ModernTheme.secondaryAccent : ModernTheme.tertiaryAccent)
                }
                ProgressView(value: percentUsed) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int(percentUsed * 100))% used")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .tint(percentUsed < 0.7 ? ModernTheme.secondaryAccent : (percentUsed < 0.9 ? .yellow : ModernTheme.tertiaryAccent))
            }
        }
        .glassCard()
    }
}

private struct BudgetItemRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let budgetItem: BudgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: budgetItem.category.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: budgetItem.category.icon)
                            .foregroundColor(.white)
                            .font(.title3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text(budgetItem.category.rawValue)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Allocated £\(String(format: "%.2f", budgetItem.allocated))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Spent £\(String(format: "%.2f", budgetItem.spent))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("£\(String(format: "%.2f", budgetItem.remaining)) left")
                        .font(.caption2)
                        .foregroundColor(budgetItem.remaining >= 0 ? ModernTheme.secondaryAccent : ModernTheme.tertiaryAccent)
                }
            }
            ProgressView(value: budgetItem.percentUsed)
                .tint(budgetItem.percentUsed < 0.7 ? ModernTheme.secondaryAccent : (budgetItem.percentUsed < 0.9 ? .yellow : ModernTheme.tertiaryAccent))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.cardCornerRadius, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: ModernTheme.cardCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 18, x: 0, y: 12)
    }
}

private struct UpcomingPaymentsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let items: [ScheduledPaymentsStore.ScheduledPaymentContext]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Payments")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.tertiaryAccent.opacity(0.5), ModernTheme.primaryAccent.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 72, height: 4)
                    .opacity(0.6)
            }

            ForEach(items) { context in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.primaryAccent.opacity(0.75), ModernTheme.secondaryAccent.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "calendar")
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.payment.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("\(context.accountName)\(context.potName != nil ? " · \(context.potName!)" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("£\(String(format: "%.2f", context.payment.amount))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(ModernTheme.tertiaryAccent)
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
        .glassCard()
    }
}

private extension Category {
    var gradient: [Color] {
        switch self {
        case .utilities:
            return [Color(red: 0.26, green: 0.52, blue: 0.98), ModernTheme.primaryAccent]
        case .food:
            return [Color(red: 0.99, green: 0.62, blue: 0.28), ModernTheme.tertiaryAccent]
        case .transport:
            return [Color(red: 0.29, green: 0.85, blue: 0.98), ModernTheme.secondaryAccent]
        case .entertainment:
            return [Color(red: 0.76, green: 0.38, blue: 0.98), ModernTheme.primaryAccent]
        case .health:
            return [Color(red: 0.24, green: 0.81, blue: 0.68), ModernTheme.secondaryAccent]
        case .shopping:
            return [Color(red: 0.98, green: 0.39, blue: 0.55), ModernTheme.tertiaryAccent]
        case .other, .salary:
            return [ModernTheme.primaryAccent, ModernTheme.secondaryAccent]
        }
    }
}

#Preview {
    BudgetView()
        .environmentObject(AccountsStore())
        .environmentObject(ScheduledPaymentsStore(accountsStore: AccountsStore()))
}
