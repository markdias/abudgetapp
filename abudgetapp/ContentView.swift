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
    @AppStorage("autoProcessTransactionsEnabled") private var autoProcessingEnabled = false
    @AppStorage("autoReduceBalancesEnabled") private var autoReduceEnabled = false
    @State private var selectedTab = 0

    var body: some View {
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
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.purple)
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
