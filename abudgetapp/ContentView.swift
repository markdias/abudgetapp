//
//  ContentView.swift
//  abudgetapp
//
//  Created by Mark Dias on 01/03/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            TransactionsView()
                .tabItem {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(1)

            TransferScheduleView()
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
    }
}

#Preview {
    ContentView()
}
