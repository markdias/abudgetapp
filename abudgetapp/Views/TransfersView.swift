import SwiftUI

struct TransfersView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeSchedulesStore: IncomeSchedulesStore
    @State private var showingIncomeSchedules = false
    @State private var isResetting = false
    @State private var showingResetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        LargeActionButton(title: "Manage Transfer Schedules", color: .blue) { }
                        LargeActionButton(title: "Manage Income Schedules", color: .green) {
                            showingIncomeSchedules = true
                        }
                        LargeActionButton(title: "Salary Sorter", color: .purple) { }
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
            .alert("Reset Balances?", isPresented: $showingResetConfirm) {
                Button("Reset", role: .destructive) {
                    Task {
                        guard !isResetting else { return }
                        isResetting = true
                        await accountsStore.resetBalances()
                        await incomeSchedulesStore.load()
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
