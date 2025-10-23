import Foundation

protocol APIServiceProtocol {
    func getAccounts() async throws -> [Account]
    func addAccount(account: AccountSubmission) async throws -> Account
    func updateAccount(accountId: Int, updatedAccount: AccountSubmission) async throws -> Account
    func deleteAccount(accountId: Int) async throws -> MessageResponse
    func updateCardOrder(accountIds: [Int]) async throws -> CardOrderResponse

    func addPot(accountId: Int, pot: PotSubmission) async throws -> Pot
    func updatePot(originalAccountId: Int, originalPot: Pot, updatedPot: PotSubmission) async throws -> Pot
    func deletePot(accountName: String, potName: String) async throws -> MessageResponse

    func addExpense(accountId: Int, expense: ExpenseSubmission) async throws -> Expense
    func addIncome(accountId: Int, income: IncomeSubmission) async throws -> Income
    func deleteExpense(accountId: Int, expenseId: Int) async throws -> MessageResponse
    func deleteIncome(accountId: Int, incomeId: Int) async throws -> MessageResponse

    func addScheduledPayment(accountId: Int, potName: String?, payment: ScheduledPaymentSubmission) async throws -> ScheduledPayment
    func deleteScheduledPayment(accountId: Int, paymentName: String, paymentDate: String, potName: String?) async throws -> MessageResponse

    func resetBalances() async throws -> ResetResponse
    func toggleAccountExclusion(accountId: Int) async throws -> ExclusionResponse
    func togglePotExclusion(accountId: Int, potName: String) async throws -> ExclusionResponse

    func getSavingsInvestments() async throws -> [Account]

    func getTransferSchedules() async throws -> [TransferSchedule]
    func addTransferSchedule(transfer: TransferScheduleSubmission) async throws -> TransferSchedule
    func executeTransferSchedule(scheduleId: Int) async throws -> TransferExecutionResponse
    func executeAllTransferSchedules() async throws -> TransferExecutionResponse
    func deleteTransferSchedule(scheduleId: Int) async throws -> MessageResponse

    func getIncomeSchedules() async throws -> [IncomeSchedule]
    func addIncomeSchedule(schedule: IncomeScheduleSubmission) async throws -> IncomeSchedule
    func executeIncomeSchedule(scheduleId: Int) async throws -> MessageResponse
    func executeAllIncomeSchedules() async throws -> IncomeExecutionResponse
    func deleteIncomeSchedule(scheduleId: Int) async throws -> MessageResponse

    func getAvailableTransfers() async throws -> AvailableTransfers
    func restoreSampleData() async throws -> ResetResponse
}

enum APIServiceError: LocalizedError {
    case notFound(String)
    case invalidOperation(String)
    case persistence(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return message
        case .invalidOperation(let message):
            return message
        case .persistence(let message):
            return "Failed to persist data: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

final class APIService: APIServiceProtocol {
    static let shared = APIService()

    private let store = LocalBudgetStore.shared

    private init() {}

    func getAccounts() async throws -> [Account] {
        await store.currentAccounts()
    }

    func addAccount(account: AccountSubmission) async throws -> Account {
        do {
            return try await store.addAccount(account)
        } catch {
            throw map(error)
        }
    }

    func updateAccount(accountId: Int, updatedAccount: AccountSubmission) async throws -> Account {
        do {
            return try await store.updateAccount(id: accountId, submission: updatedAccount)
        } catch {
            throw map(error)
        }
    }

    func deleteAccount(accountId: Int) async throws -> MessageResponse {
        do {
            try await store.deleteAccount(id: accountId)
            return MessageResponse(message: "Account deleted")
        } catch {
            throw map(error)
        }
    }

    func updateCardOrder(accountIds: [Int]) async throws -> CardOrderResponse {
        do {
            let accounts = try await store.reorderAccounts(by: accountIds)
            return CardOrderResponse(success: true, message: "Card order updated", accounts: accounts)
        } catch {
            throw map(error)
        }
    }

    func addPot(accountId: Int, pot: PotSubmission) async throws -> Pot {
        do {
            return try await store.addPot(accountId: accountId, submission: pot)
        } catch {
            throw map(error)
        }
    }

    func updatePot(originalAccountId: Int, originalPot: Pot, updatedPot: PotSubmission) async throws -> Pot {
        do {
            return try await store.updatePot(accountId: originalAccountId, potId: originalPot.id, submission: updatedPot)
        } catch {
            throw map(error)
        }
    }

    func deletePot(accountName: String, potName: String) async throws -> MessageResponse {
        do {
            try await store.deletePot(accountName: accountName, potName: potName)
            return MessageResponse(message: "Pot deleted")
        } catch {
            throw map(error)
        }
    }

    func addExpense(accountId: Int, expense: ExpenseSubmission) async throws -> Expense {
        do {
            return try await store.addExpense(accountId: accountId, submission: expense)
        } catch {
            throw map(error)
        }
    }

    func addIncome(accountId: Int, income: IncomeSubmission) async throws -> Income {
        do {
            return try await store.addIncome(accountId: accountId, submission: income)
        } catch {
            throw map(error)
        }
    }

    func deleteExpense(accountId: Int, expenseId: Int) async throws -> MessageResponse {
        do {
            try await store.deleteExpense(accountId: accountId, expenseId: expenseId)
            return MessageResponse(message: "Expense deleted")
        } catch {
            throw map(error)
        }
    }

    func deleteIncome(accountId: Int, incomeId: Int) async throws -> MessageResponse {
        do {
            try await store.deleteIncome(accountId: accountId, incomeId: incomeId)
            return MessageResponse(message: "Income deleted")
        } catch {
            throw map(error)
        }
    }

    func addScheduledPayment(accountId: Int, potName: String?, payment: ScheduledPaymentSubmission) async throws -> ScheduledPayment {
        do {
            return try await store.addScheduledPayment(accountId: accountId, potName: potName, submission: payment)
        } catch {
            throw map(error)
        }
    }

    func deleteScheduledPayment(accountId: Int, paymentName: String, paymentDate: String, potName: String?) async throws -> MessageResponse {
        do {
            try await store.deleteScheduledPayment(accountId: accountId, paymentName: paymentName, paymentDate: paymentDate, potName: potName)
            return MessageResponse(message: "Scheduled payment deleted")
        } catch {
            throw map(error)
        }
    }

    func resetBalances() async throws -> ResetResponse {
        do {
            return try await store.resetBalances()
        } catch {
            throw map(error)
        }
    }

    func toggleAccountExclusion(accountId: Int) async throws -> ExclusionResponse {
        do {
            let value = try await store.toggleAccountExclusion(accountId: accountId)
            return ExclusionResponse(excludeFromReset: value)
        } catch {
            throw map(error)
        }
    }

    func togglePotExclusion(accountId: Int, potName: String) async throws -> ExclusionResponse {
        do {
            let value = try await store.togglePotExclusion(accountId: accountId, potName: potName)
            return ExclusionResponse(excludeFromReset: value)
        } catch {
            throw map(error)
        }
    }

    func getSavingsInvestments() async throws -> [Account] {
        await store.savingsAndInvestments()
    }

    func getTransferSchedules() async throws -> [TransferSchedule] {
        await store.currentTransferSchedules()
    }

    func addTransferSchedule(transfer: TransferScheduleSubmission) async throws -> TransferSchedule {
        do {
            return try await store.addTransferSchedule(transfer)
        } catch {
            throw map(error)
        }
    }

    func executeTransferSchedule(scheduleId: Int) async throws -> TransferExecutionResponse {
        do {
            return try await store.executeTransferSchedule(id: scheduleId)
        } catch {
            throw map(error)
        }
    }

    func executeAllTransferSchedules() async throws -> TransferExecutionResponse {
        do {
            return try await store.executeAllTransferSchedules()
        } catch {
            throw map(error)
        }
    }

    func deleteTransferSchedule(scheduleId: Int) async throws -> MessageResponse {
        do {
            try await store.deleteTransferSchedule(id: scheduleId)
            return MessageResponse(message: "Transfer schedule deleted")
        } catch {
            throw map(error)
        }
    }

    func getIncomeSchedules() async throws -> [IncomeSchedule] {
        await store.currentIncomeSchedules()
    }

    func addIncomeSchedule(schedule: IncomeScheduleSubmission) async throws -> IncomeSchedule {
        do {
            return try await store.addIncomeSchedule(schedule)
        } catch {
            throw map(error)
        }
    }

    func executeIncomeSchedule(scheduleId: Int) async throws -> MessageResponse {
        do {
            return try await store.executeIncomeSchedule(id: scheduleId)
        } catch {
            throw map(error)
        }
    }

    func executeAllIncomeSchedules() async throws -> IncomeExecutionResponse {
        do {
            return try await store.executeAllIncomeSchedules()
        } catch {
            throw map(error)
        }
    }

    func deleteIncomeSchedule(scheduleId: Int) async throws -> MessageResponse {
        do {
            try await store.deleteIncomeSchedule(id: scheduleId)
            return MessageResponse(message: "Income schedule deleted")
        } catch {
            throw map(error)
        }
    }

    func getAvailableTransfers() async throws -> AvailableTransfers {
        await store.availableTransfers()
    }

    func restoreSampleData() async throws -> ResetResponse {
        do {
            return try await store.restoreSample()
        } catch {
            throw map(error)
        }
    }

    private func map(_ error: Error) -> APIServiceError {
        if let serviceError = error as? APIServiceError {
            return serviceError
        }
        if let storeError = error as? LocalBudgetStore.StoreError {
            switch storeError {
            case .notFound(let message):
                return .notFound(message)
            case .invalidOperation(let message):
                return .invalidOperation(message)
            case .persistence(let underlying):
                return .persistence(underlying.localizedDescription)
            }
        }
        return .unknown(error)
    }
}
