import SwiftUI

@main
struct MyBudgetApp: App {
    @StateObject private var accountsStore: AccountsStore
    @StateObject private var potsStore: PotsStore
    @StateObject private var incomeSchedulesStore: IncomeSchedulesStore
    @StateObject private var savingsStore: SavingsInvestmentsStore
    @StateObject private var activityStore: ActivityStore
    @StateObject private var diagnosticsStore: DiagnosticsStore
    @StateObject private var scheduledPaymentsStore: ScheduledPaymentsStore

    init() {
        let accounts = AccountsStore()
        _accountsStore = StateObject(wrappedValue: accounts)
        _potsStore = StateObject(wrappedValue: PotsStore(accountsStore: accounts))
        _incomeSchedulesStore = StateObject(wrappedValue: IncomeSchedulesStore(accountsStore: accounts))
        _savingsStore = StateObject(wrappedValue: SavingsInvestmentsStore())
        _activityStore = StateObject(wrappedValue: ActivityStore(accountsStore: accounts))
        _diagnosticsStore = StateObject(wrappedValue: DiagnosticsStore(accountsStore: accounts))
        _scheduledPaymentsStore = StateObject(wrappedValue: ScheduledPaymentsStore(accountsStore: accounts))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountsStore)
                .environmentObject(potsStore)
                .environmentObject(incomeSchedulesStore)
                .environmentObject(savingsStore)
                .environmentObject(activityStore)
                .environmentObject(diagnosticsStore)
                .environmentObject(scheduledPaymentsStore)
                .preferredColorScheme(.light)
                .accentColor(.purple)
                .task {
                    await bootstrap()
                }
        }
    }

    private func bootstrap() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await accountsStore.loadAccounts() }
            group.addTask { await savingsStore.load() }
            group.addTask { await incomeSchedulesStore.load() }
        }
    }
}
