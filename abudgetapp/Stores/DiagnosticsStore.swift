import Foundation

@MainActor
final class DiagnosticsStore: ObservableObject {
    enum StepStatus {
        case pending
        case running
        case success(String?)
        case failure(String)
    }

    struct DiagnosticStep: Identifiable {
        let id = UUID()
        let name: String
        var status: StepStatus = .pending
        var duration: TimeInterval?
    }

    @Published private(set) var steps: [DiagnosticStep] = []
    @Published var isRunning = false

    private let service: APIServiceProtocol
    private weak var accountsStore: AccountsStore?

    init(service: APIServiceProtocol = APIService.shared, accountsStore: AccountsStore? = nil) {
        self.service = service
        self.accountsStore = accountsStore
        self.steps = DiagnosticsStore.defaultSteps()
    }

    func attachAccountsStore(_ store: AccountsStore) {
        self.accountsStore = store
    }

    func runFullSuite() async {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }

        var updatedSteps = DiagnosticsStore.defaultSteps()
        steps = updatedSteps

        var createdAccountId: Int?
        var createdAccountName: String?

        let operations: [(String, () async throws -> String?)] = [
            ("Fetch Accounts", { _ = try await self.service.getAccounts(); return nil }),
            ("Add Account", {
                let submission = AccountSubmission(name: "Diagnostics \(UUID().uuidString.prefix(4))", balance: 500, type: "current", accountType: "personal")
                let account = try await self.service.addAccount(account: submission)
                createdAccountId = account.id
                createdAccountName = account.name
                return "Created account #\(account.id)"
            }),
            ("Add Pot", {
                guard let accountId = createdAccountId else { throw APIServiceError.invalidOperation("Missing account for pot") }
                let pot = try await self.service.addPot(accountId: accountId, pot: PotSubmission(name: "Diagnostics Pot", balance: 120))
                return "Added pot \(pot.name)"
            }),
            ("Delete Pot", {
                guard let accountName = createdAccountName else { throw APIServiceError.invalidOperation("Missing account for delete pot") }
                _ = try await self.service.deletePot(accountName: accountName, potName: "Diagnostics Pot")
                return "Deleted diagnostics pot"
            }),
            ("Delete Account", {
                guard let accountId = createdAccountId else { throw APIServiceError.invalidOperation("Missing account for delete") }
                _ = try await self.service.deleteAccount(accountId: accountId)
                return "Deleted diagnostics account"
            }),
            ("Execute Transfers", {
                let response = try await self.service.executeAllTransferSchedules()
                return response.success == true ? "Executed transfers" : (response.error ?? "No transfers executed")
            }),
            ("Execute Incomes", {
                let response = try await self.service.executeAllIncomeSchedules()
                return "Executed \(response.executed_count) income schedules"
            }),
            ("Reset Balances", {
                let reset = try await self.service.resetBalances()
                self.accountsStore?.applyAccounts(reset.accounts)
                return "Reset \(reset.accounts.count) accounts"
            }),
            ("Available Transfers", {
                let available = try await self.service.getAvailableTransfers()
                return "\(available.byAccount.count + available.byPot.count) groups"
            })
        ]

        for index in operations.indices {
            let (_, operation) = operations[index]
            updatedSteps[index].status = .running
            steps = updatedSteps
            let start = Date()
            do {
                let message = try await operation()
                updatedSteps[index].status = .success(message)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            } catch let error as APIServiceError {
                updatedSteps[index].status = .failure(error.localizedDescription)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            } catch {
                updatedSteps[index].status = .failure(error.localizedDescription)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            }
            steps = updatedSteps
        }

        await accountsStore?.loadAccounts()
    }

    private static func defaultSteps() -> [DiagnosticStep] {
        [
            DiagnosticStep(name: "Fetch Accounts"),
            DiagnosticStep(name: "Add Account"),
            DiagnosticStep(name: "Add Pot"),
            DiagnosticStep(name: "Delete Pot"),
            DiagnosticStep(name: "Delete Account"),
            DiagnosticStep(name: "Execute Transfers"),
            DiagnosticStep(name: "Execute Incomes"),
            DiagnosticStep(name: "Reset Balances"),
            DiagnosticStep(name: "Available Transfers")
        ]
    }
}
