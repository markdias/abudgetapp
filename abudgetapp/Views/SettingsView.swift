//
//  SettingsView.swift
//  abudgetapp
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDarkMode = false
    @State private var notificationsEnabled = true
    @State private var username = "Mark Dias"
    @State private var apiBaseURL = "http://localhost:3000"
    @State private var showingAPIStatus = false
    @State private var apiStatusMessage = ""
    @State private var apiStatusSuccess = false
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Profile")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(username)
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: Text("Profile Details View")) {
                        Text("Edit Profile")
                    }
                }
                
                Section(header: Text("API Configuration")) {
                    TextField("Server URL", text: $apiBaseURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("Test Connection") {
                        testAPIConnection()
                    }
                    
                    Button("Save API Configuration") {
                        saveAPIConfiguration()
                    }
                    .disabled(apiBaseURL.isEmpty)
                    
                    if showingAPIStatus {
                        HStack {
                            Image(systemName: apiStatusSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(apiStatusSuccess ? .green : .red)
                            Text(apiStatusMessage)
                                .font(.footnote)
                        }
                    }
                    
                    Button("Reload Data") {
                        appState.fetchData()
                    }
                }
                
                Section(header: Text("Budget Management")) {
                    Button("Reset All Balances") {
                        confirmResetBalances()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Execute All Income Schedules") {
                        executeAllIncomeSchedules()
                    }
                    
                    Button("Execute All Transfer Schedules") {
                        executeAllTransferSchedules()
                    }
                }
                
                Section(header: Text("Preferences")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    
                    NavigationLink(destination: Text("Currency Settings View")) {
                        HStack {
                            Text("Currency")
                            Spacer()
                            Text("GBP (£)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Data & Privacy")) {
                    NavigationLink(destination: Text("Export Data View")) {
                        Text("Export Data")
                    }
                    
                    NavigationLink(destination: Text("Privacy Policy View")) {
                        Text("Privacy Policy")
                    }
                    
                    Button(action: {
                        // Clear all data action
                    }) {
                        Text("Clear All Data")
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            Text("Budget App")
                                .font(.headline)
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
            .alert(isPresented: $appState.showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(appState.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                // Load the saved API URL
                apiBaseURL = APIService.shared.loadSavedURL()
            }
            .confirmationDialog(
                "Reset Balances",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    resetBalances()
                }
                Button("Cancel", role: .cancel) {
                    // Do nothing
                }
            } message: {
                Text("Are you sure you want to reset all balances? This action cannot be undone.")
            }
        }
    }
    
    // Test the API connection by making a simple request
    private func testAPIConnection() {
        showingAPIStatus = true
        apiStatusMessage = "Testing connection..."
        
        // Need to ensure the URL is valid
        guard let url = URL(string: apiBaseURL + "/accounts") else {
            apiStatusSuccess = false
            apiStatusMessage = "Invalid URL format"
            return
        }
        
        // Make a simple request to test the connection
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    apiStatusSuccess = false
                    apiStatusMessage = "Connection failed: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    apiStatusSuccess = false
                    apiStatusMessage = "Invalid response"
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    apiStatusSuccess = true
                    apiStatusMessage = "Connection successful!"
                } else {
                    apiStatusSuccess = false
                    apiStatusMessage = "Server returned status code: \(httpResponse.statusCode)"
                }
            }
        }
        task.resume()
    }
    
    // Save the API configuration
    private func saveAPIConfiguration() {
        APIService.shared.updateBaseURL(apiBaseURL)
        showingAPIStatus = true
        apiStatusSuccess = true
        apiStatusMessage = "API URL saved successfully"
        
        // Reload data with the new URL
        appState.fetchData()
    }
    
    // Reset all balances
    private func confirmResetBalances() {
        showingResetConfirmation = true
    }
    
    private func resetBalances() {
        appState.resetBalances { success in
            showingAPIStatus = true
            if success {
                apiStatusSuccess = true
                apiStatusMessage = "Balances reset successfully"
            } else {
                apiStatusSuccess = false
                apiStatusMessage = "Failed to reset balances"
            }
        }
    }
    
    private func executeAllIncomeSchedules() {
        appState.executeAllIncomeSchedules { success in
            showingAPIStatus = true
            if success {
                apiStatusSuccess = true
                apiStatusMessage = "Income schedules executed successfully"
            } else {
                apiStatusSuccess = false
                apiStatusMessage = "Failed to execute income schedules"
            }
        }
    }
    
    private func executeAllTransferSchedules() {
        appState.executeAllTransferSchedules { success in
            showingAPIStatus = true
            if success {
                apiStatusSuccess = true
                apiStatusMessage = "Transfer schedules executed successfully"
            } else {
                apiStatusSuccess = false
                apiStatusMessage = "Failed to execute transfer schedules"
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
