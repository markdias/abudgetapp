import Foundation

@MainActor
final class TransferSchedulesStore: ObservableObject {
    @Published private(set) var schedules: [TransferSchedule] = []
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
        let items = await store.currentTransferSchedules()
        schedules = items
    }

    func addSchedule(from fromAccountId: Int, fromPotName: String?, to toAccountId: Int, toPotName: String?, amount: Double, description: String) async {
        do {
            // Prevent duplicate pending schedule for same destination
            let destPot = toPotName ?? ""
            if schedules.contains(where: { $0.isActive && !$0.isCompleted && $0.toAccountId == toAccountId && ($0.toPotName ?? "") == destPot }) {
                statusMessage = StatusMessage(title: "Already Scheduled", message: "A pending schedule exists for this destination.", kind: .warning)
                return
            }
            let submission = TransferScheduleSubmission(
                fromAccountId: fromAccountId,
                fromPotName: fromPotName,
                toAccountId: toAccountId,
                toPotName: toPotName,
                amount: amount,
                description: description
            )
            _ = try await store.addTransferSchedule(submission)
            schedules = await store.currentTransferSchedules()
            statusMessage = StatusMessage(title: "Scheduled", message: "Added transfer to schedule", kind: .success)
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

    func delete(schedule: TransferSchedule) async {
        do {
            try await store.deleteTransferSchedule(id: schedule.id)
            schedules = await store.currentTransferSchedules()
            statusMessage = StatusMessage(title: "Schedule Deleted", message: "Removed transfer schedule", kind: .warning)
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

    func execute(schedule: TransferSchedule) async {
        do {
            _ = try await store.executeTransferSchedule(id: schedule.id)
            schedules = await store.currentTransferSchedules()
            await accountsStore?.loadAccounts()
            statusMessage = StatusMessage(title: "Transfer Executed", message: "Funds moved", kind: .success)
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
            _ = try await store.executeAllTransferSchedules()
            schedules = await store.currentTransferSchedules()
            await accountsStore?.loadAccounts()
            statusMessage = StatusMessage(title: "Executed All", message: "Applied all active transfers", kind: .success)
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

    func executeGroup(toAccountId: Int, toPotName: String?) async {
        // Execute all pending schedules that target this destination
        let pending = schedules.filter { $0.isActive && !$0.isCompleted && $0.toAccountId == toAccountId && ($0.toPotName ?? "") == (toPotName ?? "") }
        for item in pending {
            await execute(schedule: item)
        }
    }
}
