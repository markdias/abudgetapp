import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("autoProcessTransactionsEnabled") private var autoProcessTransactionsEnabled = false
    @AppStorage("autoReduceBalancesEnabled") private var autoReduceBalancesEnabled = false

    @State private var storageStatus: String?
    @State private var storageStatusIsSuccess = false
    @State private var showingCardReorder = false
    @State private var showingDiagnostics = false
    @State private var showingDeleteAllConfirm = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = JSONDocument()

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        appearanceCard
                        activitiesCard
                        automationCard
                        storageCard
                        dataManagementCard
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
            // Removed Income Schedules; now lives under Transfers
            .alert("Delete All Data?", isPresented: $showingDeleteAllConfirm) {
                Button("Delete", role: .destructive) { Task { await deleteAllData() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently erase all accounts, pots, and schedules. This cannot be undone.")
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
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

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Automation")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.tertiaryAccent.opacity(0.45), ModernTheme.primaryAccent.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 68, height: 4)
                    .opacity(0.7)
            }
            Toggle(isOn: $autoProcessTransactionsEnabled) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Process Transactions Automatically")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Runs whenever the app launches.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $autoReduceBalancesEnabled) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reduce Balances Automatically")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Adjusts balances when the app becomes active.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
