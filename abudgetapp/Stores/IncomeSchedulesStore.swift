import Foundation

@MainActor
final class IncomeSchedulesStore: ObservableObject {
    @Published private(set) var schedules: [IncomeSchedule] = []
    @Published var isLoading = false
    @Published var lastMessage: StatusMessage?
    @Published var lastError: APIServiceError?

    private let service: APIServiceProtocol
    private weak var accountsStore: AccountsStore?

    init(service: APIServiceProtocol = APIService.shared, accountsStore: AccountsStore? = nil) {
        self.service = service
        self.accountsStore = accountsStore
    }

    func attachAccountsStore(_ store: AccountsStore) {
        self.accountsStore = store
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        do {
            schedules = try await service.getIncomeSchedules()
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Income Schedules", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Income Schedules", message: apiError.localizedDescription, kind: .error)
        }
    }

    func add(_ submission: IncomeScheduleSubmission) async {
        do {
            let schedule = try await service.addIncomeSchedule(schedule: submission)
            schedules.append(schedule)
            lastMessage = StatusMessage(title: "Income Scheduled", message: schedule.description, kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Add Income Schedule Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Add Income Schedule Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func execute(scheduleId: Int) async {
        do {
            _ = try await service.executeIncomeSchedule(scheduleId: scheduleId)
            schedules = try await service.getIncomeSchedules()
            lastMessage = StatusMessage(title: "Income Executed", message: "Executed income schedule", kind: .success)
            if let accountsStore = accountsStore {
                await accountsStore.loadAccounts()
            }
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Execute Income Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Execute Income Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func executeAll() async {
        do {
            let response = try await service.executeAllIncomeSchedules()
            schedules = try await service.getIncomeSchedules()
            accountsStore?.applyAccounts(response.accounts)
            lastMessage = StatusMessage(title: "Income Executed", message: "Executed \(response.executed_count) schedules", kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Execute All Incomes Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Execute All Incomes Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func delete(scheduleId: Int) async {
        do {
            _ = try await service.deleteIncomeSchedule(scheduleId: scheduleId)
            schedules.removeAll { $0.id == scheduleId }
            lastMessage = StatusMessage(title: "Income Deleted", message: "Removed income schedule", kind: .warning)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Delete Income Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Delete Income Failed", message: apiError.localizedDescription, kind: .error)
        }
    }
}
