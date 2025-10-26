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

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        LargeActionButton(title: "Transfer Schedules", color: .blue) { showingTransferSchedules = true }
                        LargeActionButton(title: "Income Schedules", color: .green) {
                            showingIncomeSchedules = true
                        }
                        LargeActionButton(title: "Processed Transactions", color: .teal) {
                            showingProcessedTransactions = true
                        }
                        LargeActionButton(title: "Salary Sorter", color: .purple) { showingSalarySorter = true }
                        LargeActionButton(title: "Reset Balance", color: .red) {
                            showingResetConfirm = true
                        }
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Transfers")
            .sheet(isPresented: $showingIncomeSchedules) {
                ManageIncomeSchedulesView(isPresented: $showingIncomeSchedules)
            }
            .sheet(isPresented: $showingTransferSchedules) {
                ManageTransferSchedulesView(isPresented: $showingTransferSchedules)
            }
            .sheet(isPresented: $showingSalarySorter) {
                SalarySorterView(isPresented: $showingSalarySorter)
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
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .foregroundStyle(.white)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: color.opacity(0.18), radius: 8, x: 0, y: 4)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    TransfersView()
}
