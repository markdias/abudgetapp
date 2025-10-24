import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                ActivitiesPanelSection(
                    accounts: accountsStore.accounts,
                    transactions: accountsStore.transactions,
                    targets: accountsStore.targets,
                    selectedAccountId: nil,
                    limit: Int.max
                )
                .padding()
            }
            .navigationTitle("Activity")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    ActivitiesView()
        .environmentObject(AccountsStore())
}

