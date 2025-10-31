import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue

    @State private var storageStatus: String?
    @State private var storageStatusIsSuccess = false
    @State private var showingCardReorder = false
    @State private var showingDiagnostics = false
    @State private var showingDeleteAllConfirm = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = JSONDocument()
    @State private var showingExecutionManagement = false
    @State private var executionLogs: [ExecutionLog] = []

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        appearanceCard
                        activitiesCard
                        storageCard
                        dataManagementCard
                        logsCard
                        diagnosticsCard
                        aboutCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCardReorder) {
                CardReorderView(isPresented: $showingCardReorder)
            }
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticsRunnerView(isPresented: $showingDiagnostics)
            }
            .sheet(isPresented: $showingExecutionManagement) {
                ExecutionManagementView()
            }
            // Removed Income Schedules; now lives under Transfers
            .alert("Delete All Data?", isPresented: $showingDeleteAllConfirm) {
                Button("Delete", role: .destructive) { Task { await deleteAllData() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently erase all accounts, pots, and schedules. This cannot be undone.")
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .onAppear {
                executionLogs = ExecutionLogsManager.getLogs()
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

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Appearance")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.primaryAccent.opacity(0.45), ModernTheme.secondaryAccent.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60, height: 4)
                    .opacity(0.7)
            }
            Picker("App Appearance", selection: $appAppearanceRaw) {
                Text("Always Light").tag(AppAppearance.light.rawValue)
                Text("Always Dark").tag(AppAppearance.dark.rawValue)
                Text("System Settings").tag(AppAppearance.system.rawValue)
            }
            .pickerStyle(.segmented)
        }
        .glassCard()
    }

    private var activitiesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activities")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.secondaryAccent.opacity(0.45), ModernTheme.primaryAccent.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 64, height: 4)
                    .opacity(0.7)
            }
            VStack(alignment: .leading, spacing: 12) {
                Picker("Sort By", selection: activitiesSortBinding) {
                    Text("Name").tag("name")
                    Text("Day").tag("day")
                    Text("Type").tag("type")
                    Text("Value").tag("value")
                }
                .pickerStyle(.menu)
                Stepper(value: activitiesMaxItemsBinding, in: 1...50) {
                    HStack {
                        Text("Items on Home")
                        Spacer()
                        Text("\(activitiesMaxItems)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassCard()
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Local Storage")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.secondaryAccent.opacity(0.45), ModernTheme.primaryAccent.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 72, height: 4)
                    .opacity(0.7)
            }
            Label("Data is stored securely on this device and synced automatically.", systemImage: "internaldrive")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let status = storageStatus {
                Label(status, systemImage: storageStatusIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(storageStatusIsSuccess ? Color.green : Color.orange)
                    .font(.caption)
            }
        }
        .glassCard()
    }

    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Data Management")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.primaryAccent.opacity(0.45), ModernTheme.tertiaryAccent.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 72, height: 4)
                    .opacity(0.7)
            }
            Menu {
                Button("Reload Data") { refreshAll() }
                Button("Import Data (JSON)") { showingImporter = true }
                Button("Export Data (JSON)") { Task { await exportAllData() } }
                Button("Delete All Data", role: .destructive) { showingDeleteAllConfirm = true }
                    .disabled(accountsStore.accounts.isEmpty)
            } label: {
                Label("Manage Data", systemImage: "gearshape.2")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                            )
                    )
            }
        }
        .glassCard()
    }

    private var logsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Execution Logs")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.tertiaryAccent.opacity(0.45), ModernTheme.secondaryAccent.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 64, height: 4)
                    .opacity(0.7)
            }

            let recentLogs = executionLogs.prefix(20)
            if recentLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No execution logs yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(recentLogs), id: \.id) { log in
                        executionLogRow(log: log)
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button(action: {
                    ExecutionLogsManager.clearAllLogs()
                    executionLogs = []
                }) {
                    Label("Clear All Logs", systemImage: "trash")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                .disabled(executionLogs.isEmpty)
                .opacity(executionLogs.isEmpty ? 0.5 : 1.0)

                Spacer()
            }
        }
        .glassCard()
    }

    private func executionLogRow(log: ExecutionLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.processName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    HStack(spacing: 8) {
                        Text(dateFormatter(log.executedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if log.wasAutomatic {
                            Label("Auto", systemImage: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else {
                            Label("Manual", systemImage: "hand.tap.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(log.itemCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(log.itemCount == 1 ? "item" : "items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.3))
            .cornerRadius(8)
        }
    }

    private func dateFormatter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Utilities")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.secondaryAccent.opacity(0.45), ModernTheme.primaryAccent.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60, height: 4)
                    .opacity(0.7)
            }
            Button {
                showingDiagnostics = true
            } label: {
                Label("Run Diagnostics", systemImage: "stethoscope.circle.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                            )
                    )
            }
            Button {
                showingCardReorder = true
            } label: {
                Label("Reorder Cards", systemImage: "rectangle.3.group.bubble")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                            )
                    )
            }
            Button {
                showingExecutionManagement = true
            } label: {
                Label("Execution Management", systemImage: "clock.badge.xmark")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                            )
                    )
            }
        }
        .glassCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The Budget App")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Crafted to give you complete control of your money, now with a clean Monzo-inspired glow.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
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
    let accounts = AccountsStore()
    let diagnostics = DiagnosticsStore(accountsStore: accounts)
    return SettingsView()
        .environmentObject(accounts)
        .environmentObject(diagnostics)
}
// MARK: - Appearance Preference
enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark
}
