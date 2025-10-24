import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var incomeStore: IncomeSchedulesStore
    @EnvironmentObject private var savingsStore: SavingsInvestmentsStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore

    @State private var storageStatus: String?
    @State private var storageStatusIsSuccess = false
    @State private var isRestoringSample = false
    @State private var showingCardReorder = false
    @State private var showingDiagnostics = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Local Storage") {
                    Label("Data is stored securely on this device and synced between views automatically.", systemImage: "internaldrive")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .padding(.vertical, 4)
                    Button("Restore Sample Dataset", role: .destructive) { restoreSampleData() }
                        .disabled(isRestoringSample)
                    if let status = storageStatus {
                        Label(status, systemImage: storageStatusIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(storageStatusIsSuccess ? .green : .orange)
                            .font(.caption)
                    }
                }

                Section("Data Management") {
                    Button("Reload Data") { refreshAll() }
                    Button("Reset Balances", role: .destructive) {
                        Task { await accountsStore.resetBalances(); await incomeStore.load() }
                    }
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

    private func refreshAll() {
        Task {
            await accountsStore.loadAccounts()
            await savingsStore.load()
            await incomeStore.load()
        }
    }

    private func restoreSampleData() {
        if isRestoringSample { return }
        storageStatus = nil
        isRestoringSample = true
        Task {
            do {
                let snapshot = try await APIService.shared.restoreSampleData()
                await MainActor.run {
                    accountsStore.applyAccounts(snapshot.accounts)
                    storageStatus = "Sample data restored"
                    storageStatusIsSuccess = true
                }
                await incomeStore.load()
                await savingsStore.load()
            } catch let error as APIServiceError {
                await MainActor.run {
                    storageStatus = error.localizedDescription
                    storageStatusIsSuccess = false
                }
            } catch {
                let apiError = APIServiceError.unknown(error)
                await MainActor.run {
                    storageStatus = apiError.localizedDescription
                    storageStatusIsSuccess = false
                }
            }
            await MainActor.run {
                isRestoringSample = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AccountsStore())
        .environmentObject(IncomeSchedulesStore(accountsStore: AccountsStore()))
        .environmentObject(SavingsInvestmentsStore())
        .environmentObject(DiagnosticsStore(accountsStore: AccountsStore()))
}
