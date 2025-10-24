import Foundation

@MainActor
final class IncomeSchedulesStore: ObservableObject {
    @Published private(set) var schedules: [IncomeSchedule] = []
    @Published var isLoading = false
    @Published var lastMessage: StatusMessage?
    @Published var lastError: BudgetDataError?

    private let store: LocalBudgetStore
    private weak var accountsStore: AccountsStore?

    init(store: LocalBudgetStore = .shared, accountsStore: AccountsStore? = nil) {
        self.store = store
        self.accountsStore = accountsStore
    }

    func attachAccountsStore(_ store: AccountsStore) {
        self.accountsStore = store
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        schedules = await store.currentIncomeSchedules()
    }

    func add(_ submission: IncomeScheduleSubmission) async {
        do {
            let schedule = try await store.addIncomeSchedule(submission)
            schedules.append(schedule)
            lastMessage = StatusMessage(title: "Income Scheduled", message: schedule.description, kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            lastMessage = StatusMessage(title: "Add Income Schedule Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            lastMessage = StatusMessage(title: "Add Income Schedule Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func execute(scheduleId: Int) async {
        do {
            _ = try await store.executeIncomeSchedule(id: scheduleId)
            schedules = await store.currentIncomeSchedules()
            lastMessage = StatusMessage(title: "Income Executed", message: "Executed income schedule", kind: .success)
            if let accountsStore = accountsStore {
                await accountsStore.loadAccounts()
            }
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            lastMessage = StatusMessage(title: "Execute Income Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            lastMessage = StatusMessage(title: "Execute Income Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func executeAll() async {
        do {
            let response = try await store.executeAllIncomeSchedules()
            schedules = await store.currentIncomeSchedules()
            accountsStore?.applyAccounts(response.accounts)
            lastMessage = StatusMessage(title: "Income Executed", message: "Executed \(response.executed_count) schedules", kind: .success)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            lastMessage = StatusMessage(title: "Execute All Incomes Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            lastMessage = StatusMessage(title: "Execute All Incomes Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    func delete(scheduleId: Int) async {
        do {
            try await store.deleteIncomeSchedule(id: scheduleId)
            schedules.removeAll { $0.id == scheduleId }
            lastMessage = StatusMessage(title: "Income Deleted", message: "Removed income schedule", kind: .warning)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            lastMessage = StatusMessage(title: "Delete Income Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            lastMessage = StatusMessage(title: "Delete Income Failed", message: dataError.localizedDescription, kind: .error)
        }
    }
}
