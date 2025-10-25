import Foundation

@MainActor
final class IncomeSchedulesStore: ObservableObject {
    @Published private(set) var schedules: [IncomeSchedule] = []
    @Published var isLoading = false
    @Published var lastError: BudgetDataError?
    @Published var statusMessage: StatusMessage?

    private let store: LocalBudgetStore
    private weak var accountsStore: AccountsStore?

    init(store: LocalBudgetStore = .shared, accountsStore: AccountsStore? = nil) {
        self.store = store
        self.accountsStore = accountsStore
    }

    func attachAccountsStore(_ accounts: AccountsStore) {
        self.accountsStore = accounts
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        let items = await store.currentIncomeSchedules()
        schedules = items
    }

    func addSchedule(for accountId: Int, income: Income) async {
        do {
            // Prevent duplicate schedules for the same income on the same account
            if schedules.contains(where: { $0.accountId == accountId && $0.incomeId == income.id }) {
                statusMessage = StatusMessage(title: "Already Scheduled", message: "This income is already scheduled.", kind: .warning)
                return
            }
            let submission = IncomeScheduleSubmission(
                accountId: accountId,
                incomeId: income.id,
                amount: income.amount,
                description: income.description,
                company: income.company
            )
            _ = try await store.addIncomeSchedule(submission)
            schedules = await store.currentIncomeSchedules()
            statusMessage = StatusMessage(title: "Scheduled", message: "Added income to schedule", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Schedule Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Schedule Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func delete(schedule: IncomeSchedule) async {
        do {
            try await store.deleteIncomeSchedule(id: schedule.id)
            schedules = await store.currentIncomeSchedules()
            statusMessage = StatusMessage(title: "Schedule Deleted", message: "Removed income schedule", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Delete Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func execute(schedule: IncomeSchedule) async {
        do {
            _ = try await store.executeIncomeSchedule(id: schedule.id)
            schedules = await store.currentIncomeSchedules()
            await accountsStore?.loadAccounts()
            statusMessage = StatusMessage(title: "Income Executed", message: "Applied to account", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Execute Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Execute Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func executeAll() async {
        do {
            _ = try await store.executeAllIncomeSchedules()
            schedules = await store.currentIncomeSchedules()
            await accountsStore?.loadAccounts()
            statusMessage = StatusMessage(title: "Executed All", message: "Applied all active schedules", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            statusMessage = StatusMessage(title: "Execute All Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            statusMessage = StatusMessage(title: "Execute All Failed", message: dataError.localizedDescription, kind: .error)
        }
    }
}
