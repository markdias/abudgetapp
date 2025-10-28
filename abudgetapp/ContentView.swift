//
//  ContentView.swift
//  abudgetapp
//
//  Created by Mark Dias on 01/03/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("autoProcessTransactionsEnabled") private var autoProcessingEnabled = false
    @AppStorage("autoReduceBalancesEnabled") private var autoReduceEnabled = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            ModernTheme.background(for: colorScheme)
                .ignoresSafeArea()
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    }
                    .tag(0)

                ActivitiesView()
                    .tabItem {
                        Label("Activity", systemImage: selectedTab == 1 ? "chart.bar.doc.horizontal.fill" : "chart.bar.doc.horizontal")
                    }
                    .tag(1)

                TransfersView()
                    .tabItem {
                        Label("Transfers", systemImage: selectedTab == 2 ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == 3 ? "slider.horizontal.3" : "slider.horizontal.3")
                    }
                    .tag(3)
            }
            .tint(ModernTheme.primaryAccent)
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
