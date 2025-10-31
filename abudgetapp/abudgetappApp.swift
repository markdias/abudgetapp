import SwiftUI
import UIKit

@main
struct MyBudgetApp: App {
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("autoProcessTransactionsEnabled") private var autoProcessTransactionsEnabled = false
    @AppStorage("autoReduceBalancesEnabled") private var autoReduceBalancesEnabled = false
    @AppStorage("autoProcessOnDayEnabled") private var autoProcessOnDayEnabled = false
    @AppStorage("autoProcessDay") private var autoProcessDay: Int = 1
    @AppStorage("autoProcessHour") private var autoProcessHour: Int = 8
    @AppStorage("autoProcessMinute") private var autoProcessMinute: Int = 0
    @AppStorage("lastAutoProcessDate") private var lastAutoProcessDate: String = ""
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
        configureAppearance()
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
        // Auto-enable processing on scheduled day/time
        if autoProcessOnDayEnabled && shouldAutoProcessToday() {
            autoProcessTransactionsEnabled = true
            lastAutoProcessDate = ISO8601DateFormatter().string(from: Date())
        }
        if autoProcessTransactionsEnabled {
            await accountsStore.processScheduledTransactions()
        }
        if autoReduceBalancesEnabled {
            await accountsStore.applyMonthlyReduction()
        }
    }

    private func shouldAutoProcessToday() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: now)
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        // Check if today matches the configured day
        guard currentDay == autoProcessDay else { return false }

        // Check if current time is at or past the scheduled time
        let scheduledMinutes = autoProcessHour * 60 + autoProcessMinute
        let currentMinutes = currentHour * 60 + currentMinute

        // Check if we already processed today
        let lastDate = lastAutoProcessDate
        let formatter = ISO8601DateFormatter()
        if let lastProcessDate = formatter.date(from: lastDate) {
            let lastProcessDay = calendar.component(.day, from: lastProcessDate)
            let lastProcessMonth = calendar.component(.month, from: lastProcessDate)
            let lastProcessYear = calendar.component(.year, from: lastProcessDate)

            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)

            // If we already processed today, don't process again
            if lastProcessDay == currentDay && lastProcessMonth == currentMonth && lastProcessYear == currentYear {
                return false
            }
        }

        return currentMinutes >= scheduledMinutes
    }

}

// MARK: - Appearance mapping used by App
private extension MyBudgetApp {
    func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        navAppearance.backgroundColor = UIColor.clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 30, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(ModernTheme.primaryAccent)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tabAppearance.backgroundColor = UIColor.clear
        tabAppearance.inlineLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        tabAppearance.inlineLayoutAppearance.selected.iconColor = UIColor(ModernTheme.primaryAccent)
        tabAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        tabAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(ModernTheme.primaryAccent)
        ]
        tabAppearance.stackedLayoutAppearance = tabAppearance.inlineLayoutAppearance
        tabAppearance.compactInlineLayoutAppearance = tabAppearance.inlineLayoutAppearance
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
        UITabBar.appearance().tintColor = UIColor(ModernTheme.primaryAccent)

        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
    }

    var mappedColorScheme: ColorScheme? {
        guard let pref = AppAppearance(rawValue: appAppearanceRaw) else { return nil }
        switch pref {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
