import Foundation

@MainActor
final class TransferSchedulesStore: ObservableObject {
    struct Group: Identifiable {
        let id: String
        let title: String
        let schedules: [TransferSchedule]
        let subtitle: String?
    }

    @Published private(set) var schedules: [TransferSchedule] = []
    @Published private(set) var lastResetAt: String?
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
            let fetched = try await service.getTransferSchedules()
            schedules = fetched
            lastResetAt = await service.getLastResetAt()
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Transfers", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Transfers", message: apiError.localizedDescription, kind: .error)
        }
    }

    func add(_ submission: TransferScheduleSubmission) async {
        do {
            let schedule = try await service.addTransferSchedule(transfer: submission)
            schedules.append(schedule)
            lastMessage = StatusMessage(title: "Transfer Scheduled", message: schedule.description, kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Add Transfer Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Add Transfer Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func update(id: Int, submission: TransferScheduleSubmission) async {
        do {
            let schedule = try await service.updateTransferSchedule(scheduleId: id, transfer: submission)
            if let idx = schedules.firstIndex(where: { $0.id == id }) {
                schedules[idx] = schedule
            }
            lastMessage = StatusMessage(title: "Transfer Updated", message: schedule.description, kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Update Transfer Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Update Transfer Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func execute(scheduleId: Int) async {
        do {
            let response = try await service.executeTransferSchedule(scheduleId: scheduleId)
            if let updatedAccounts = response.accounts {
                accountsStore?.applyAccounts(updatedAccounts)
            }
            schedules = try await service.getTransferSchedules()
            if response.success == true {
                lastMessage = StatusMessage(title: "Transfer Executed", message: "Transfer schedule \(scheduleId) executed", kind: .success)
            } else if let error = response.error {
                lastMessage = StatusMessage(title: "Transfer Execution", message: error, kind: .warning)
            }
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Execute Transfer Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Execute Transfer Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func executeAll() async {
        do {
            let response = try await service.executeAllTransferSchedules()
            if let updatedAccounts = response.accounts {
                accountsStore?.applyAccounts(updatedAccounts)
            }
            schedules = try await service.getTransferSchedules()
            if response.success == true {
                lastMessage = StatusMessage(title: "Transfers Executed", message: "All transfer schedules executed", kind: .success)
            } else if let error = response.error {
                lastMessage = StatusMessage(title: "Transfers Executed", message: error, kind: .warning)
            }
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Execute All Transfers Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Execute All Transfers Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func delete(scheduleId: Int) async {
        do {
            _ = try await service.deleteTransferSchedule(scheduleId: scheduleId)
            schedules.removeAll { $0.id == scheduleId }
            lastMessage = StatusMessage(title: "Transfer Deleted", message: "Removed transfer schedule", kind: .warning)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Delete Transfer Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Delete Transfer Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func groupsByDestination() -> [Group] {
        var grouped: [String: [TransferSchedule]] = [:]
        for schedule in schedules {
            let key = "to-\(schedule.toAccountId)-\(schedule.toPotName ?? "account")"
            grouped[key, default: []].append(schedule)
        }

        return grouped.map { key, schedules in
            let components = key.split(separator: "-")
            let title: String
            var subtitle: String?
            if let accountIdValue = components.dropFirst().first, let accountId = Int(accountIdValue) {
                if let account = accountsStore?.account(for: accountId) {
                    title = account.name
                    subtitle = scheduleDestinationSubtitle(schedules.first, account: account)
                } else {
                    title = "Account #\(accountId)"
                    subtitle = scheduleDestinationSubtitle(schedules.first, account: nil)
                }
            } else {
                title = "Destination"
                subtitle = scheduleDestinationSubtitle(schedules.first, account: nil)
            }
            return Group(id: key, title: title, schedules: schedules, subtitle: subtitle)
        }
        .sorted { $0.title < $1.title }
    }

    private func scheduleDestinationSubtitle(_ schedule: TransferSchedule?, account _: Account?) -> String? {
        guard let schedule else { return nil }
        if let potName = schedule.toPotName, !potName.isEmpty {
            return "Pot: \(potName)"
        }
        return "Pot: —"
    }
}
