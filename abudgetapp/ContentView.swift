//
//  ContentView.swift
//  abudgetapp
//
//  Created by Mark Dias on 01/03/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("autoProcessTransactionsEnabled") private var autoProcessingEnabled = false
    @AppStorage("autoReduceBalancesEnabled") private var autoReduceEnabled = false
    @State private var selectedTab = 0

    init() {
#if canImport(UIKit)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        tabBarAppearance.backgroundColor = UIColor(BrandTheme.tabBarBackground)
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(BrandTheme.accent)
        tabBarAppearance.inlineLayoutAppearance.selected.iconColor = UIColor(BrandTheme.accent)
        tabBarAppearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(BrandTheme.accent)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(BrandTheme.accent)]
        tabBarAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(BrandTheme.accent)]
        tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(BrandTheme.accent)]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
#endif
    }

    var body: some View {
        ZStack {
            BrandBackground()

            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                ActivitiesView()
                    .tabItem {
                        Label("Activity", systemImage: "list.bullet")
                    }
                    .tag(1)

                TransfersView()
                    .tabItem {
                        Label("Transfers", systemImage: "arrow.left.arrow.right")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(BrandTheme.accent)
            .onAppear {
#if canImport(UIKit)
                UITabBar.appearance().unselectedItemTintColor = UIColor(BrandTheme.accentSecondary.opacity(0.6))
#endif
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard autoProcessingEnabled || autoReduceEnabled else { return }
            Task {
                if autoProcessingEnabled {
                    await accountsStore.processScheduledTransactions()
                }
                if autoReduceEnabled {
                    await accountsStore.applyMonthlyReduction()
                }
            }
        }
    }
}

#Preview {
    let accounts = AccountsStore()
    return ContentView()
        .environmentObject(accounts)
        .environmentObject(PotsStore(accountsStore: accounts))
        .environmentObject(DiagnosticsStore(accountsStore: accounts))
        .environmentObject(ScheduledPaymentsStore(accountsStore: accounts))
        .environmentObject(IncomeSchedulesStore(accountsStore: accounts))
        .environmentObject(TransferSchedulesStore(accountsStore: accounts))
}
