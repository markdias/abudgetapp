import Foundation

@MainActor
final class AccountsStore: ObservableObject {
    static let accountsDidChangeNotification = Notification.Name("AccountsStoreAccountsDidChange")

    @Published private(set) var accounts: [Account] = [] {
        didSet { publishAccountsChange() }
    }
    // Removed transactions tracking
    @Published private(set) var transactions: [TransactionRecord] = []
    @Published private(set) var targets: [TargetRecord] = []
    @Published var isLoading = false
    @Published var statusMessage: StatusMessage?
    @Published var lastError: BudgetDataError?

    private let store: LocalBudgetStore

    init(store: LocalBudgetStore = .shared) {
        self.store = store
    }

    func loadAccounts(force: Bool = false) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        let fetchedAccounts = await store.currentAccounts()
        accounts = fetchedAccounts
        transactions = await store.currentTransactions()
        targets = await store.currentTargets()
        // Removed transfer queue; no pruning needed
    }

    func addAccount(_ submission: AccountSubmission) async {
        do {
            let account = try await store.addAccount(submission)
            accounts.append(account)
            statusMessage = StatusMessage(title: "Account Added", message: "Successfully added \(account.name)", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Account Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Account Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func updateAccount(id: Int, submission: AccountSubmission) async {
        do {
            let updatedAccount = try await store.updateAccount(id: id, submission: submission)
            applyAccount(updatedAccount)
            statusMessage = StatusMessage(title: "Account Updated", message: "Updated \(updatedAccount.name)", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Account Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Account Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func deleteAccount(id: Int) async {
        do {
            try await store.deleteAccount(id: id)
            accounts.removeAll { $0.id == id }
            statusMessage = StatusMessage(title: "Account Deleted", message: "Removed account", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Account Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Account Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    // Removed income, expense, and transaction management methods
    // MARK: - Income Management

    func addIncome(accountId: Int, submission: IncomeSubmission) async {
        do {
            _ = try await store.addIncome(accountId: accountId, submission: submission)
            await loadAccounts()
            statusMessage = StatusMessage(title: "Income Added", message: "Income recorded successfully", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Income Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Income Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func updateIncome(accountId: Int, incomeId: Int, submission: IncomeSubmission) async {
        do {
            _ = try await store.updateIncome(accountId: accountId, incomeId: incomeId, submission: submission)
            await loadAccounts()
            statusMessage = StatusMessage(title: "Income Updated", message: "Income updated successfully", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Income Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Income Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func deleteIncome(accountId: Int, incomeId: Int) async {
        do {
            try await store.deleteIncome(accountId: accountId, incomeId: incomeId)
            await loadAccounts()
            statusMessage = StatusMessage(title: "Income Deleted", message: "Income removed", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Income Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Income Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func resetBalances() async {
        do {
            _ = try await store.resetBalances()
            // Reload full state so all dependent views (activities, pots) refresh immediately
            await loadAccounts()
            statusMessage = StatusMessage(title: "Balances Reset", message: "Accounts have been reset", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Reset Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Reset Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func reorderAccounts(fromOffsets: IndexSet, toOffset: Int) async {
        let reordered = accounts.moving(fromOffsets: fromOffsets, toOffset: toOffset)
        accounts = reordered
        do {
            let ids = accounts.map { $0.id }
            accounts = try await store.reorderAccounts(by: ids)
            statusMessage = StatusMessage(title: "Card Order", message: "Card order updated", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Reorder Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Reorder Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func applyAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
    }

    func applyAccounts(_ newAccounts: [Account]) {
        accounts = newAccounts
    }

    func mutateAccount(id: Int, transform: (inout Account) -> Void) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        var account = accounts[index]
        transform(&account)
        accounts[index] = account
    }

    func account(for id: Int) -> Account? {
        accounts.first { $0.id == id }
    }

    // MARK: - Transactions

    func addTransaction(_ submission: TransactionSubmission) async {
        do {
            _ = try await store.addTransaction(submission)
            transactions = await store.currentTransactions()
            statusMessage = StatusMessage(title: "Transaction Added", message: "Recorded successfully", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Transaction Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Transaction Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func updateTransaction(id: Int, submission: TransactionSubmission) async {
        do {
            _ = try await store.updateTransaction(id: id, submission: submission)
            transactions = await store.currentTransactions()
            statusMessage = StatusMessage(title: "Transaction Updated", message: "Updated successfully", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Transaction Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Transaction Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func deleteTransaction(id: Int) async {
        do {
            try await store.deleteTransaction(id: id)
            transactions = await store.currentTransactions()
            statusMessage = StatusMessage(title: "Transaction Deleted", message: "Removed", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Transaction Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Transaction Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func transaction(for id: Int) -> TransactionRecord? {
        transactions.first { $0.id == id }
    }

    @discardableResult
    func processScheduledTransactionsIfNeeded(upTo date: Date) async -> Int {
        guard UserDefaults.standard.bool(forKey: "processTransactionsEnabled") else { return 0 }
        do {
            let processed = try await store.processScheduledTransactions(upTo: date)
            guard !processed.isEmpty else { return 0 }
            await loadAccounts()
            let count = processed.count
            let suffix = count == 1 ? "scheduled payment" : "scheduled payments"
            statusMessage = StatusMessage(
                title: "Transactions Processed",
                message: "Processed \(count) \(suffix).",
                kind: .success
            )
            return count
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(
                title: "Process Transactions Failed",
                message: dataError.localizedDescription,
                kind: .error
            )
            return 0
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(
                title: "Process Transactions Failed",
                message: dataError.localizedDescription,
                kind: .error
            )
            return 0
        }
    }

    // MARK: - Targets
    func addTarget(_ submission: TargetSubmission) async {
        do {
            _ = try await store.addTarget(submission)
            targets = await store.currentTargets()
            statusMessage = StatusMessage(title: "Target Added", message: "Recorded successfully", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Target Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Target Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func updateTarget(id: Int, submission: TargetSubmission) async {
        do {
            _ = try await store.updateTarget(id: id, submission: submission)
            targets = await store.currentTargets()
            statusMessage = StatusMessage(title: "Target Updated", message: "Updated successfully", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Target Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Target Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func deleteTarget(id: Int) async {
        do {
            try await store.deleteTarget(id: id)
            targets = await store.currentTargets()
            statusMessage = StatusMessage(title: "Target Deleted", message: "Removed", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Target Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Target Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    // Transfer scheduling removed

    private func publishAccountsChange() {
        NotificationCenter.default.post(
            name: AccountsStore.accountsDidChangeNotification,
            object: nil,
            userInfo: [
                "accounts": accounts
            ]
        )
    }

    // No transfer queue to prune
}

private extension Array where Element == Account {
    func moving(fromOffsets: IndexSet, toOffset: Int) -> [Account] {
        var copy = self
        copy.move(fromOffsets: fromOffsets, toOffset: toOffset)
        return copy
    }
}
