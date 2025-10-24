import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore

    @State private var storageStatus: String?
    @State private var storageStatusIsSuccess = false
    @State private var isRestoringSample = false
    @State private var showingCardReorder = false
    @State private var showingDiagnostics = false
    @State private var showingDeleteAllConfirm = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = JSONDocument()

    var body: some View {
        NavigationStack {
            Form {
                Section("Activities") {
                    Picker("Sort By", selection: activitiesSortBinding) {
                        Text("Name").tag("name")
                        Text("Day").tag("day")
                        Text("Type").tag("type")
                    }
                    Stepper(value: activitiesMaxItemsBinding, in: 1...50) {
                        HStack {
                            Text("Items on Home")
                            Spacer()
                            Text("\(activitiesMaxItems)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
                    Button("Import Data (JSON)") { showingImporter = true }
                    Button("Export Data (JSON)") { Task { await exportAllData() } }
                    Button("Delete All Data", role: .destructive) { showingDeleteAllConfirm = true }
                        .tint(.red)
                        .disabled(accountsStore.accounts.isEmpty)
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
            .alert("Delete All Data?", isPresented: $showingDeleteAllConfirm) {
                Button("Delete", role: .destructive) { Task { await deleteAllData() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently erase all accounts, pots, and schedules. This cannot be undone.")
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    do {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        _ = try await LocalBudgetStore.shared.importStateData(data)
                        await accountsStore.loadAccounts()
                        await MainActor.run {
                            storageStatus = "Budget restored from file"
                            storageStatusIsSuccess = true
                        }
                    } catch let error as LocalBudgetStore.StoreError {
                        let dataError = error.asBudgetDataError
                        await MainActor.run {
                            storageStatus = dataError.localizedDescription
                            storageStatusIsSuccess = false
                        }
                    } catch {
                        let dataError = BudgetDataError.unknown(error)
                        await MainActor.run {
                            storageStatus = dataError.localizedDescription
                            storageStatusIsSuccess = false
                        }
                    }
                }
            case .failure:
                break
            }
        }
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json, defaultFilename: "budget_state") { result in
            if case .failure(let error) = result {
                storageStatus = error.localizedDescription
                storageStatusIsSuccess = false
            } else {
                storageStatus = "Exported budget to file"
                storageStatusIsSuccess = true
            }
        }
    }

    // MARK: - Preferences
    @AppStorage("activitiesSortOrder") private var activitiesSortOrder: String = "day"
    @AppStorage("activitiesMaxItems") private var activitiesMaxItems: Int = 6
    private var activitiesSortBinding: Binding<String> {
        Binding<String>(
            get: { activitiesSortOrder },
            set: { activitiesSortOrder = $0 }
        )
    }
    private var activitiesMaxItemsBinding: Binding<Int> {
        Binding<Int>(
            get: { activitiesMaxItems },
            set: { activitiesMaxItems = $0 }
        )
    }

    private func refreshAll() {
        Task {
            await accountsStore.loadAccounts()
        }
    }

    private func restoreSampleData() {
        if isRestoringSample { return }
        storageStatus = nil
        isRestoringSample = true
        Task {
            do {
                let snapshot = try await LocalBudgetStore.shared.restoreSample()
                await MainActor.run {
                    accountsStore.applyAccounts(snapshot.accounts)
                    storageStatus = "Sample data restored"
                    storageStatusIsSuccess = true
                }
            } catch let error as LocalBudgetStore.StoreError {
                let dataError = error.asBudgetDataError
                await MainActor.run {
                    storageStatus = dataError.localizedDescription
                    storageStatusIsSuccess = false
                }
            } catch {
                let apiError = BudgetDataError.unknown(error)
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

    private func deleteAllData() async {
        do {
            _ = try await LocalBudgetStore.shared.clearAll()
            await MainActor.run {
                storageStatus = "All data cleared"
                storageStatusIsSuccess = true
            }
            await accountsStore.loadAccounts()
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            await MainActor.run {
                storageStatus = dataError.localizedDescription
                storageStatusIsSuccess = false
            }
        } catch {
            let apiError = BudgetDataError.unknown(error)
            await MainActor.run {
                storageStatus = apiError.localizedDescription
                storageStatusIsSuccess = false
            }
        }
    }

    private func exportAllData() async {
        do {
            let data = try await LocalBudgetStore.shared.exportStateData()
            await MainActor.run {
                exportDocument = JSONDocument(data: data)
                showingExporter = true
            }
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            await MainActor.run {
                storageStatus = dataError.localizedDescription
                storageStatusIsSuccess = false
            }
        } catch {
            let dataError = BudgetDataError.unknown(error)
            await MainActor.run {
                storageStatus = dataError.localizedDescription
                storageStatusIsSuccess = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AccountsStore())
        .environmentObject(DiagnosticsStore(accountsStore: AccountsStore()))
}
