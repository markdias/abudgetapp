import Foundation

@MainActor
final class AccountsStore: ObservableObject {
    static let accountsDidChangeNotification = Notification.Name("AccountsStoreAccountsDidChange")

    @Published private(set) var accounts: [Account] = [] {
        didSet { publishAccountsChange() }
    }
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

        let fetched = await store.currentAccounts()
        accounts = fetched
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

    private func publishAccountsChange() {
        NotificationCenter.default.post(
            name: AccountsStore.accountsDidChangeNotification,
            object: nil,
            userInfo: ["accounts": accounts]
        )
    }
}

private extension Array where Element == Account {
    func moving(fromOffsets: IndexSet, toOffset: Int) -> [Account] {
        var copy = self
        copy.move(fromOffsets: fromOffsets, toOffset: toOffset)
        return copy
    }
}
