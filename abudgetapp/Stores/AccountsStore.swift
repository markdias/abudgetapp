import Foundation

@MainActor
final class AccountsStore: ObservableObject {
    static let accountsDidChangeNotification = Notification.Name("AccountsStoreAccountsDidChange")

    @Published private(set) var accounts: [Account] = [] {
        didSet { publishAccountsChange() }
    }
    @Published var isLoading = false
    @Published var statusMessage: StatusMessage?
    @Published var lastError: APIServiceError?

    private let service: APIServiceProtocol

    init(service: APIServiceProtocol = APIService.shared) {
        self.service = service
    }

    func loadAccounts(force: Bool = false) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await service.getAccounts()
            accounts = fetched
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Accounts", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Accounts", message: apiError.localizedDescription, kind: .error)
        }
    }

    func addAccount(_ submission: AccountSubmission) async {
        do {
            let account = try await service.addAccount(account: submission)
            accounts.append(account)
            statusMessage = StatusMessage(title: "Account Added", message: "Successfully added \(account.name)", kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Add Account Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Add Account Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func updateAccount(id: Int, submission: AccountSubmission) async {
        do {
            let updatedAccount = try await service.updateAccount(accountId: id, updatedAccount: submission)
            applyAccount(updatedAccount)
            statusMessage = StatusMessage(title: "Account Updated", message: "Updated \(updatedAccount.name)", kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Update Account Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Update Account Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func deleteAccount(id: Int) async {
        do {
            _ = try await service.deleteAccount(accountId: id)
            accounts.removeAll { $0.id == id }
            statusMessage = StatusMessage(title: "Account Deleted", message: "Removed account", kind: .warning)
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Delete Account Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Delete Account Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func addIncome(accountId: Int, submission: IncomeSubmission) async {
        do {
            let income = try await service.addIncome(accountId: accountId, income: submission)
            mutateAccount(id: accountId) { account in
                var incomes = account.incomes ?? []
                incomes.append(income)
                account.incomes = incomes
            }
            statusMessage = StatusMessage(title: "Income Added", message: income.description, kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Add Income Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Add Income Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func addExpense(accountId: Int, submission: ExpenseSubmission) async {
        do {
            let expense = try await service.addExpense(accountId: accountId, expense: submission)
            mutateAccount(id: accountId) { account in
                var expenses = account.expenses ?? []
                expenses.append(expense)
                account.expenses = expenses
            }
            statusMessage = StatusMessage(title: "Expense Added", message: expense.description, kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Add Expense Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Add Expense Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func resetBalances() async {
        do {
            let response = try await service.resetBalances()
            accounts = response.accounts
            statusMessage = StatusMessage(title: "Balances Reset", message: "Accounts have been reset", kind: .warning)
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Reset Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Reset Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func reorderAccounts(fromOffsets: IndexSet, toOffset: Int) async {
        let reordered = accounts.moving(fromOffsets: fromOffsets, toOffset: toOffset)
        accounts = reordered
        do {
            let ids = accounts.map { $0.id }
            let response = try await service.updateCardOrder(accountIds: ids)
            if let returnedAccounts = response.accounts {
                accounts = returnedAccounts
            }
            statusMessage = StatusMessage(title: "Card Order", message: response.message ?? "Card order updated", kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            statusMessage = StatusMessage(title: "Reorder Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            statusMessage = StatusMessage(title: "Reorder Failed", message: apiError.localizedDescription, kind: .error)
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
