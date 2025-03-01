//
//  ContentView.swift
//  abudgetapp
//
//  Created by Mark Dias on 01/03/2025.
//

import SwiftUI

struct ContentView: View {
    // Add access to the app state
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
            
            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(.purple) // Monzo-inspired color
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState()) // Add this for previews to work
}
