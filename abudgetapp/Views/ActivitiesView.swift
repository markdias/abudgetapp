import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @State private var selectedAccountId: Int? = nil
    @State private var selectedPotName: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Filters Section (Activities screen only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filters").font(.headline)
                        Picker("Account", selection: $selectedAccountId) {
                            Text("All Accounts").tag(nil as Int?)
                            ForEach(accountsStore.accounts) { account in
                                Text(account.name).tag(account.id as Int?)
                            }
                        }
                        .pickerStyle(.menu)

                        if let id = selectedAccountId,
                           let account = accountsStore.account(for: id),
                           let pots = account.pots, !pots.isEmpty {
                            Picker("Pot", selection: $selectedPotName) {
                                Text("All Pots").tag(nil as String?)
                                ForEach(pots, id: \.name) { pot in
                                    Text(pot.name).tag(pot.name as String?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    ActivitiesPanelSection(
                        accounts: accountsStore.accounts,
                        transactions: accountsStore.transactions,
                        targets: accountsStore.targets,
                        selectedAccountId: selectedAccountId,
                        limit: Int.max,
                        selectedPotName: selectedPotName
                    )
                }
                .padding()
            }
            .navigationTitle("Activity")
            .background(Color(.systemGroupedBackground))
            .onChange(of: selectedAccountId) { _, _ in selectedPotName = nil }
        }
    }
}

#Preview {
    ActivitiesView()
        .environmentObject(AccountsStore())
}
