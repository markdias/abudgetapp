import SwiftUI

@main
struct MyBudgetApp: App {
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue
    @StateObject private var accountsStore: AccountsStore
    @StateObject private var potsStore: PotsStore
    @StateObject private var diagnosticsStore: DiagnosticsStore
    @StateObject private var scheduledPaymentsStore: ScheduledPaymentsStore
    @StateObject private var incomeSchedulesStore: IncomeSchedulesStore
    @StateObject private var transferSchedulesStore: TransferSchedulesStore

    init() {
        let accounts = AccountsStore()
        _accountsStore = StateObject(wrappedValue: accounts)
        _potsStore = StateObject(wrappedValue: PotsStore(accountsStore: accounts))
        _diagnosticsStore = StateObject(wrappedValue: DiagnosticsStore(accountsStore: accounts))
        _scheduledPaymentsStore = StateObject(wrappedValue: ScheduledPaymentsStore(accountsStore: accounts))
        let incomeStore = IncomeSchedulesStore(accountsStore: accounts)
        _incomeSchedulesStore = StateObject(wrappedValue: incomeStore)
        let transferStore = TransferSchedulesStore(accountsStore: accounts)
        _transferSchedulesStore = StateObject(wrappedValue: transferStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountsStore)
                .environmentObject(potsStore)
                .environmentObject(diagnosticsStore)
                .environmentObject(scheduledPaymentsStore)
                .environmentObject(incomeSchedulesStore)
                .environmentObject(transferSchedulesStore)
                .preferredColorScheme(mappedColorScheme)
                .accentColor(.purple)
                .task {
                    await bootstrap()
                }
        }
    }

    private func bootstrap() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await accountsStore.loadAccounts() }
        }
    }
}

// MARK: - Appearance mapping used by App
private extension MyBudgetApp {
    var mappedColorScheme: ColorScheme? {
        guard let pref = AppAppearance(rawValue: appAppearanceRaw) else { return nil }
        switch pref {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
