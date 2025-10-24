import Foundation

@MainActor
final class AccountsStore: ObservableObject {
    static let accountsDidChangeNotification = Notification.Name("AccountsStoreAccountsDidChange")

    @Published private(set) var accounts: [Account] = [] {
        didSet { publishAccountsChange() }
    }
    @Published private(set) var transactions: [TransactionRecord] = [] {
        didSet { publishAccountsChange() }
    }
    @Published private(set) var transferQueue: [TransferScheduleItem] = []
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

        let fetchedTransactions = await store.currentTransactions()
        let fetchedAccounts = await store.currentAccounts()
        transactions = fetchedTransactions
        accounts = fetchedAccounts
        pruneTransferQueue()
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

    func addIncome(accountId: Int, submission: IncomeSubmission) async {
        do {
            let income = try await store.addIncome(accountId: accountId, submission: submission)
            mutateAccount(id: accountId) { account in
                var incomes = account.incomes ?? []
                incomes.append(income)
                account.incomes = incomes
            }
            statusMessage = StatusMessage(title: "Income Added", message: income.description, kind: .success)
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
            statusMessage = StatusMessage(title: "Income Updated", message: submission.description, kind: .success)
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

    func addExpense(accountId: Int, submission: ExpenseSubmission) async {
        do {
            let expense = try await store.addExpense(accountId: accountId, submission: submission)
            mutateAccount(id: accountId) { account in
                var expenses = account.expenses ?? []
                expenses.append(expense)
                account.expenses = expenses
            }
            statusMessage = StatusMessage(title: "Expense Added", message: expense.description, kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Expense Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Add Expense Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func updateExpense(accountId: Int, expenseId: Int, submission: ExpenseSubmission) async {
        do {
            _ = try await store.updateExpense(accountId: accountId, expenseId: expenseId, submission: submission)
            await loadAccounts()
            statusMessage = StatusMessage(title: "Expense Updated", message: submission.description, kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Expense Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Update Expense Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func deleteIncome(accountId: Int, incomeId: Int) async {
        do {
            try await store.deleteIncome(accountId: accountId, incomeId: incomeId)
            await loadAccounts()
            statusMessage = StatusMessage(title: "Income Deleted", message: "Removed income", kind: .warning)
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

    func deleteExpense(accountId: Int, expenseId: Int) async {
        do {
            try await store.deleteExpense(accountId: accountId, expenseId: expenseId)
            await loadAccounts()
            statusMessage = StatusMessage(title: "Expense Deleted", message: "Removed expense", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Expense Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Expense Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func addTransaction(_ submission: TransactionSubmission) async {
        do {
            _ = try await store.addTransaction(submission)
            await loadAccounts()
            statusMessage = StatusMessage(title: "Transaction Added", message: submission.name, kind: .success)
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
            await loadAccounts()
            statusMessage = StatusMessage(title: "Transaction Updated", message: submission.name, kind: .success)
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
            await loadAccounts()
            statusMessage = StatusMessage(title: "Transaction Deleted", message: "Removed transaction", kind: .warning)
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

    func resetBalances() async {
        do {
            let response = try await store.resetBalances()
            accounts = response.accounts
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

    func transaction(for id: Int) -> TransactionRecord? {
        transactions.first { $0.id == id }
    }

    func transferCandidates(fromAccountId: Int) -> [TransferScheduleItem] {
        guard let account = account(for: fromAccountId) else { return [] }
        guard let expenses = account.expenses, !expenses.isEmpty else { return [] }

        struct Key: Hashable {
            let toAccountId: Int
            let toPotName: String?
        }

        var grouped: [Key: (amount: Double, contexts: [TransferScheduleItem.Context])] = [:]

        for expense in expenses {
            guard expense.amount > 0 else { continue }
            let hasDestinationAccount = expense.toAccountId != nil
            let hasDestinationPot = (expense.toPotName?.isEmpty == false)
            guard hasDestinationAccount || hasDestinationPot else { continue }

            let destinationAccountId = expense.toAccountId ?? account.id
            guard let destinationAccount = self.account(for: destinationAccountId) else { continue }

            let key = Key(toAccountId: destinationAccountId, toPotName: expense.toPotName)
            var existing = grouped[key] ?? (amount: 0, contexts: [])
            existing.amount += expense.amount
            existing.contexts.append(TransferScheduleItem.Context(
                expenseId: expense.id,
                description: expense.description,
                amount: expense.amount,
                date: expense.date
            ))
            grouped[key] = existing
        }

        let items: [TransferScheduleItem] = grouped.compactMap { key, value in
            guard let destinationAccount = account(for: key.toAccountId) else { return nil }
            return TransferScheduleItem(
                fromAccountId: account.id,
                fromAccountName: account.name,
                toAccountId: destinationAccount.id,
                toAccountName: destinationAccount.name,
                toPotName: key.toPotName,
                amount: value.amount,
                contexts: value.contexts
            )
        }

        return items.sorted { lhs, rhs in
            if lhs.destinationDisplayName == rhs.destinationDisplayName {
                return lhs.amount > rhs.amount
            }
            return lhs.destinationDisplayName.localizedCaseInsensitiveCompare(rhs.destinationDisplayName) == .orderedAscending
        }
    }

    func enqueueTransfer(_ item: TransferScheduleItem) {
        guard !transferQueue.contains(where: { $0.id == item.id }) else { return }
        transferQueue.append(item)
    }

    func dequeueTransfer(_ item: TransferScheduleItem) {
        transferQueue.removeAll { $0.id == item.id }
    }

    func clearTransferQueue() {
        transferQueue.removeAll()
    }

    func isTransferQueued(_ item: TransferScheduleItem) -> Bool {
        transferQueue.contains(where: { $0.id == item.id })
    }

    func executeQueuedTransfers() async {
        guard !transferQueue.isEmpty else { return }

        let items = transferQueue
        do {
            for item in items {
                let submission = TransactionSubmission(
                    name: "Transfer to \(item.destinationDisplayName)",
                    vendor: "Transfer Schedule",
                    amount: item.amount,
                    date: nil,
                    fromAccountId: item.fromAccountId,
                    toAccountId: item.toAccountId,
                    toPotName: item.toPotName
                )
                _ = try await store.addTransaction(submission)
            }
            transferQueue.removeAll()
            await loadAccounts()
            statusMessage = StatusMessage(
                title: "Transfers Executed",
                message: "Moved scheduled transfer amounts",
                kind: .success
            )
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Execute Transfers Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Execute Transfers Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    private func publishAccountsChange() {
        NotificationCenter.default.post(
            name: AccountsStore.accountsDidChangeNotification,
            object: nil,
            userInfo: [
                "accounts": accounts,
                "transactions": transactions
            ]
        )
    }

    private func pruneTransferQueue() {
        guard !transferQueue.isEmpty else { return }
        transferQueue.removeAll { item in
            guard let _ = account(for: item.fromAccountId),
                  let destinationAccount = account(for: item.toAccountId) else { return true }
            if let potName = item.toPotName, !potName.isEmpty {
                let potExists = destinationAccount.pots?.contains(where: { $0.name.caseInsensitiveCompare(potName) == .orderedSame }) ?? false
                return !potExists
            }
            return false
        }
    }
}

private extension Array where Element == Account {
    func moving(fromOffsets: IndexSet, toOffset: Int) -> [Account] {
        var copy = self
        copy.move(fromOffsets: fromOffsets, toOffset: toOffset)
        return copy
    }
}
