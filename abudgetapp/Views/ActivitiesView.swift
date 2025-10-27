import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @State private var selectedAccountId: Int? = nil
    @State private var selectedPotName: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Focus your feed")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(LinearGradient(colors: [BrandTheme.accentSecondary, BrandTheme.accent], startPoint: .leading, endPoint: .trailing))

                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Account", selection: $selectedAccountId) {
                                    Text("All Accounts").tag(nil as Int?)
                                    ForEach(accountsStore.accounts) { account in
                                        Text(account.name).tag(account.id as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)

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
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .font(.system(.callout, design: .rounded))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandCardStyle()

                        ActivitiesPanelSection(
                            accounts: accountsStore.accounts,
                            transactions: accountsStore.transactions,
                            targets: accountsStore.targets,
                            selectedAccountId: selectedAccountId,
                            limit: Int.max,
                            selectedPotName: selectedPotName
                        )
                        .brandCardStyle()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onChange(of: selectedAccountId) { _, _ in selectedPotName = nil }
        }
    }
}

#Preview {
    ActivitiesView()
        .environmentObject(AccountsStore())
}
