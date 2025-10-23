import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @EnvironmentObject private var savingsStore: SavingsInvestmentsStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore

    @State private var apiBaseURL = APIService.shared.loadSavedURL()
    @State private var apiStatusMessage: String?
    @State private var apiStatusSuccess = false
    @State private var showingCardReorder = false
    @State private var showingDiagnostics = false

    var body: some View {
        NavigationStack {
            Form {
                Section("API Configuration") {
                    TextField("Base URL", text: $apiBaseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button("Save") { saveAPIConfiguration() }
                    Button("Test Connection") { Task { await testConnection() } }
                    if let status = apiStatusMessage {
                        Label(status, systemImage: apiStatusSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(apiStatusSuccess ? .green : .red)
                            .font(.caption)
                    }
                }

                Section("Data Management") {
                    Button("Reload Data") { refreshAll() }
                    Button("Reset Balances", role: .destructive) {
                        Task { await accountsStore.resetBalances(); await transferStore.load(); await incomeStore.load() }
                    }
                    Button("Execute All Transfers") { Task { await transferStore.executeAll() } }
                        .disabled(transferStore.schedules.isEmpty)
                    Button("Execute All Incomes") { Task { await incomeStore.executeAll() } }
                        .disabled(incomeStore.schedules.isEmpty)
                }

                Section("Tools") {
                    Button("Reorder Cards") { showingCardReorder = true }
                    Button("Run Diagnostics") { showingDiagnostics = true }
                }

                Section("About") {
                    VStack(alignment: .leading) {
                        Text("MyBudget")
                            .font(.headline)
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCardReorder) {
                CardReorderView(isPresented: $showingCardReorder)
            }
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticsRunnerView(isPresented: $showingDiagnostics)
            }
        }
    }

    private func saveAPIConfiguration() {
        APIService.shared.updateBaseURL(apiBaseURL)
        apiStatusMessage = "Saved"
        apiStatusSuccess = true
        refreshAll()
    }

    private func refreshAll() {
        Task {
            await accountsStore.loadAccounts()
            await savingsStore.load()
            await transferStore.load()
            await incomeStore.load()
        }
    }

    private func testConnection() async {
        guard let url = URL(string: apiBaseURL) else {
            apiStatusMessage = "Invalid URL"
            apiStatusSuccess = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                apiStatusMessage = "Connection Successful"
                apiStatusSuccess = true
            } else {
                apiStatusMessage = "Unexpected Response"
                apiStatusSuccess = false
            }
        } catch {
            apiStatusMessage = error.localizedDescription
            apiStatusSuccess = false
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AccountsStore())
        .environmentObject(TransferSchedulesStore(accountsStore: AccountsStore()))
        .environmentObject(IncomeSchedulesStore(accountsStore: AccountsStore()))
        .environmentObject(SavingsInvestmentsStore())
        .environmentObject(DiagnosticsStore(accountsStore: AccountsStore()))
}
