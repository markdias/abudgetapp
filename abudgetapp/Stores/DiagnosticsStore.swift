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

    private let store: LocalBudgetStore
    private weak var accountsStore: AccountsStore?

    init(store: LocalBudgetStore = .shared, accountsStore: AccountsStore? = nil) {
        self.store = store
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
            ("Fetch Accounts", { _ = await self.store.currentAccounts(); return nil }),
            ("Add Account", {
                let submission = AccountSubmission(name: "Diagnostics \(UUID().uuidString.prefix(4))", balance: 500, type: "current", accountType: "personal")
                let account = try await self.store.addAccount(submission)
                createdAccountId = account.id
                createdAccountName = account.name
                return "Created account #\(account.id)"
            }),
            ("Add Pot", {
                guard let accountId = createdAccountId else { throw BudgetDataError.invalidOperation("Missing account for pot") }
                let pot = try await self.store.addPot(accountId: accountId, submission: PotSubmission(name: "Diagnostics Pot", balance: 120))
                return "Added pot \(pot.name)"
            }),
            ("Delete Pot", {
                guard let accountName = createdAccountName else { throw BudgetDataError.invalidOperation("Missing account for delete pot") }
                try await self.store.deletePot(accountName: accountName, potName: "Diagnostics Pot")
                return "Deleted diagnostics pot"
            }),
            ("Delete Account", {
                guard let accountId = createdAccountId else { throw BudgetDataError.invalidOperation("Missing account for delete") }
                try await self.store.deleteAccount(id: accountId)
                return "Deleted diagnostics account"
            }),
            ("Reset Balances", {
                let reset = try await self.store.resetBalances()
                self.accountsStore?.applyAccounts(reset.accounts)
                return "Reset \(reset.accounts.count) accounts"
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
            } catch let error as LocalBudgetStore.StoreError {
                updatedSteps[index].status = .failure(error.asBudgetDataError.localizedDescription)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            } catch let dataError as BudgetDataError {
                updatedSteps[index].status = .failure(dataError.localizedDescription)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            } catch {
                let fallback = BudgetDataError.unknown(error)
                updatedSteps[index].status = .failure(fallback.localizedDescription)
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
            DiagnosticStep(name: "Reset Balances")
        ]
    }
}
