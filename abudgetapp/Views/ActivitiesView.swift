import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAccountId: Int? = nil
    @State private var selectedPotName: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Filter Activity")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                Spacer()
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [ModernTheme.secondaryAccent.opacity(0.4), ModernTheme.primaryAccent.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 64, height: 4)
                                    .opacity(0.6)
                            }
                            Text("Dive into recent income, payments, and targets across all of your accounts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 12) {
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
                        }
                        .glassCard()

                        ActivitiesPanelSection(
                            accounts: accountsStore.accounts,
                            transactions: accountsStore.transactions,
                            targets: accountsStore.targets,
                            selectedAccountId: selectedAccountId,
                            limit: Int.max,
                            selectedPotName: selectedPotName
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Activity")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .onChange(of: selectedAccountId) { _, _ in selectedPotName = nil }
        }
    }
}

#Preview {
    ActivitiesView()
        .environmentObject(AccountsStore())
}
