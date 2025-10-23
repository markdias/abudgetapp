import Foundation

actor LocalBudgetStore {
    enum StoreError: Error {
        case notFound(String)
        case invalidOperation(String)
        case persistence(Error)
    }

    static let shared = LocalBudgetStore()

    private var state: BudgetState
    private let persistenceURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.persistenceURL = LocalBudgetStore.makePersistenceURL()

        if let data = try? Data(contentsOf: persistenceURL),
           let loaded = try? decoder.decode(BudgetState.self, from: data) {
            self.state = loaded.normalized()
        } else {
            self.state = BudgetState.sample.normalized()
            // Avoid persisting during actor initialization to satisfy Swift 6 isolation rules.
        }
    }

    // MARK: - Public API

    func currentAccounts() -> [Account] {
        state.accounts
    }

    func currentTransferSchedules() -> [TransferSchedule] {
        state.transferSchedules
    }

    func currentIncomeSchedules() -> [IncomeSchedule] {
        state.incomeSchedules
    }

    func addAccount(_ submission: AccountSubmission) throws -> Account {
        let account = Account(
            id: state.nextAccountId,
            name: submission.name,
            balance: submission.balance,
            type: submission.type,
            accountType: submission.accountType,
            credit_limit: submission.credit_limit,
            excludeFromReset: submission.excludeFromReset ?? false,
            pots: [],
            scheduled_payments: [],
            incomes: [],
            expenses: []
        )
        state.nextAccountId += 1
        state.accounts.append(account)
        try persist()
        return account
    }

    func updateAccount(id: Int, submission: AccountSubmission) throws -> Account {
        guard let index = state.accounts.firstIndex(where: { $0.id == id }) else {
            throw StoreError.notFound("Account #\(id) not found")
        }
        let existing = state.accounts[index]
        let updated = Account(
            id: existing.id,
            name: submission.name,
            balance: submission.balance,
            type: submission.type,
            accountType: submission.accountType,
            credit_limit: submission.credit_limit ?? existing.credit_limit,
            excludeFromReset: submission.excludeFromReset ?? existing.excludeFromReset,
            pots: existing.pots,
            scheduled_payments: existing.scheduled_payments,
            incomes: existing.incomes,
            expenses: existing.expenses
        )
        state.accounts[index] = updated
        try persist()
        return updated
    }

    func deleteAccount(id: Int) throws {
        guard let index = state.accounts.firstIndex(where: { $0.id == id }) else {
            throw StoreError.notFound("Account #\(id) not found")
        }
        state.accounts.remove(at: index)
        state.transferSchedules.removeAll { $0.toAccountId == id || $0.fromAccountId == id }
        state.incomeSchedules.removeAll { $0.accountId == id }
        try persist()
    }

    func reorderAccounts(by identifiers: [Int]) throws -> [Account] {
        var reordered: [Account] = []
        for id in identifiers {
            if let account = state.accounts.first(where: { $0.id == id }) {
                reordered.append(account)
            }
        }
        let remaining = state.accounts.filter { account in
            !identifiers.contains(account.id)
        }
        state.accounts = reordered + remaining
        try persist()
        return state.accounts
    }

    func addPot(accountId: Int, submission: PotSubmission) throws -> Pot {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        var pots = account.pots ?? []
        guard !pots.contains(where: { $0.name.caseInsensitiveCompare(submission.name) == .orderedSame }) else {
            throw StoreError.invalidOperation("A pot with that name already exists")
        }
        let pot = Pot(
            id: state.nextPotId,
            name: submission.name,
            balance: submission.balance,
            excludeFromReset: submission.excludeFromReset ?? false,
            scheduled_payments: []
        )
        state.nextPotId += 1
        pots.append(pot)
        account.pots = pots
        state.accounts[index] = account
        try persist()
        return pot
    }

    func updatePot(accountId: Int, potId: Int, submission: PotSubmission) throws -> Pot {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var pots = account.pots, let potIndex = pots.firstIndex(where: { $0.id == potId }) else {
            throw StoreError.notFound("Pot #\(potId) not found")
        }
        let updated = Pot(
            id: potId,
            name: submission.name,
            balance: submission.balance,
            excludeFromReset: submission.excludeFromReset ?? pots[potIndex].excludeFromReset,
            scheduled_payments: pots[potIndex].scheduled_payments
        )
        pots[potIndex] = updated
        account.pots = pots
        state.accounts[index] = account
        try persist()
        return updated
    }

    func deletePot(accountName: String, potName: String) throws {
        guard let accountIndex = state.accounts.firstIndex(where: { $0.name == accountName }) else {
            throw StoreError.notFound("Account \(accountName) not found")
        }
        var account = state.accounts[accountIndex]
        guard var pots = account.pots, let potIndex = pots.firstIndex(where: { $0.name == potName }) else {
            throw StoreError.notFound("Pot \(potName) not found")
        }
        pots.remove(at: potIndex)
        account.pots = pots
        state.accounts[accountIndex] = account
        try persist()
    }

    func addIncome(accountId: Int, submission: IncomeSubmission) throws -> Income {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        var incomes = account.incomes ?? []
        let income = Income(
            id: state.nextIncomeId,
            amount: submission.amount,
            description: submission.description,
            company: submission.company,
            date: submission.date ?? LocalBudgetStore.isoFormatter.string(from: Date())
        )
        state.nextIncomeId += 1
        incomes.append(income)
        account.incomes = incomes
        account.balance += submission.amount
        state.accounts[index] = account
        try persist()
        return income
    }

    func addExpense(accountId: Int, submission: ExpenseSubmission) throws -> Expense {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        var expenses = account.expenses ?? []
        let expense = Expense(
            id: state.nextExpenseId,
            amount: submission.amount,
            description: submission.description,
            date: submission.date ?? LocalBudgetStore.isoFormatter.string(from: Date())
        )
        state.nextExpenseId += 1
        expenses.append(expense)
        account.expenses = expenses
        account.balance -= submission.amount
        state.accounts[index] = account
        try persist()
        return expense
    }

    func deleteIncome(accountId: Int, incomeId: Int) throws {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var incomes = account.incomes, let incomeIndex = incomes.firstIndex(where: { $0.id == incomeId }) else {
            throw StoreError.notFound("Income #\(incomeId) not found")
        }
        let income = incomes.remove(at: incomeIndex)
        account.incomes = incomes
        account.balance -= income.amount
        state.accounts[index] = account
        try persist()
    }

    func deleteExpense(accountId: Int, expenseId: Int) throws {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var expenses = account.expenses, let expenseIndex = expenses.firstIndex(where: { $0.id == expenseId }) else {
            throw StoreError.notFound("Expense #\(expenseId) not found")
        }
        let expense = expenses.remove(at: expenseIndex)
        account.expenses = expenses
        account.balance += expense.amount
        state.accounts[index] = account
        try persist()
    }

    func addScheduledPayment(accountId: Int, potName: String?, submission: ScheduledPaymentSubmission) throws -> ScheduledPayment {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        let payment = ScheduledPayment(
            id: state.nextScheduledPaymentId,
            name: submission.name,
            amount: submission.amount,
            date: submission.date,
            company: submission.company,
            type: submission.type,
            isCompleted: submission.isCompleted ?? false,
            lastExecuted: submission.lastExecuted
        )
        state.nextScheduledPaymentId += 1
        if let potName, !potName.isEmpty {
            try updatePotScheduledPayment(accountIndex: index, potName: potName) { payments in
                payments.append(payment)
            }
        } else {
            var account = state.accounts[index]
            var payments = account.scheduled_payments ?? []
            payments.append(payment)
            account.scheduled_payments = payments
            state.accounts[index] = account
        }
        try persist()
        return payment
    }

    func deleteScheduledPayment(accountId: Int, paymentName: String, paymentDate: String, potName: String?) throws {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        if let potName, !potName.isEmpty {
            try updatePotScheduledPayment(accountIndex: index, potName: potName) { payments in
                payments.removeAll { $0.name == paymentName && $0.date == paymentDate }
            }
        } else {
            var account = state.accounts[index]
            account.scheduled_payments?.removeAll { $0.name == paymentName && $0.date == paymentDate }
            state.accounts[index] = account
        }
        try persist()
    }

    func toggleAccountExclusion(accountId: Int) throws -> Bool {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        let current = account.excludeFromReset ?? false
        account.excludeFromReset = !current
        state.accounts[index] = account
        try persist()
        return account.excludeFromReset ?? false
    }

    func togglePotExclusion(accountId: Int, potName: String) throws -> Bool {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var pots = account.pots, let potIndex = pots.firstIndex(where: { $0.name == potName }) else {
            throw StoreError.notFound("Pot \(potName) not found")
        }
        var pot = pots[potIndex]
        let current = pot.excludeFromReset ?? false
        pot.excludeFromReset = !current
        pots[potIndex] = pot
        account.pots = pots
        state.accounts[index] = account
        try persist()
        return pot.excludeFromReset ?? false
    }

    func resetBalances() throws -> ResetResponse {
        for index in state.accounts.indices {
            var account = state.accounts[index]
            if account.excludeFromReset != true {
                account.balance = 0
            }
            if var pots = account.pots {
                for potIndex in pots.indices {
                    if pots[potIndex].excludeFromReset != true {
                        pots[potIndex].balance = 0
                    }
                }
                account.pots = pots
            }
            state.accounts[index] = account
        }
        try persist()
        return ResetResponse(accounts: state.accounts, income_schedules: state.incomeSchedules, transfer_schedules: state.transferSchedules)
    }

    func savingsAndInvestments() -> [Account] {
        state.accounts.filter { account in
            let type = account.type.lowercased()
            let category = account.accountType?.lowercased() ?? ""
            return type == "savings" || type == "investment" || category == "investment"
        }
    }

    func addTransferSchedule(_ submission: TransferScheduleSubmission) throws -> TransferSchedule {
        guard state.accounts.contains(where: { $0.id == submission.toAccountId }) else {
            throw StoreError.notFound("Destination account #\(submission.toAccountId) not found")
        }
        let schedule = TransferSchedule(
            id: state.nextTransferScheduleId,
            fromAccountId: submission.fromAccountId,
            fromPotId: submission.fromPotId,
            toAccountId: submission.toAccountId,
            toPotName: submission.toPotName,
            amount: submission.amount,
            description: submission.description,
            isActive: true,
            isCompleted: false,
            items: submission.items,
            isDirectPotTransfer: submission.isDirectPotTransfer,
            lastExecuted: nil
        )
        state.nextTransferScheduleId += 1
        state.transferSchedules.append(schedule)
        try persist()
        return schedule
    }

    func executeTransferSchedule(id: Int) throws -> TransferExecutionResponse {
        guard let index = state.transferSchedules.firstIndex(where: { $0.id == id }) else {
            throw StoreError.notFound("Transfer schedule #\(id) not found")
        }
        var schedule = state.transferSchedules[index]
        guard schedule.isActive else {
            return TransferExecutionResponse(success: false, accounts: state.accounts, error: "Schedule is inactive")
        }
        try applyTransfer(schedule)
        schedule.isCompleted = true
        schedule.lastExecuted = LocalBudgetStore.isoFormatter.string(from: Date())
        state.transferSchedules[index] = schedule
        try persist()
        return TransferExecutionResponse(success: true, accounts: state.accounts, error: nil)
    }

    func executeAllTransferSchedules() throws -> TransferExecutionResponse {
        var executedCount = 0
        for index in state.transferSchedules.indices {
            if state.transferSchedules[index].isActive && !state.transferSchedules[index].isCompleted {
                let schedule = state.transferSchedules[index]
                try applyTransfer(schedule)
                state.transferSchedules[index].isCompleted = true
                state.transferSchedules[index].lastExecuted = LocalBudgetStore.isoFormatter.string(from: Date())
                executedCount += 1
            }
        }
        try persist()
        if executedCount == 0 {
            return TransferExecutionResponse(success: false, accounts: state.accounts, error: "No active schedules to execute")
        }
        return TransferExecutionResponse(success: true, accounts: state.accounts, error: nil)
    }

    func deleteTransferSchedule(id: Int) throws {
        guard let index = state.transferSchedules.firstIndex(where: { $0.id == id }) else {
            throw StoreError.notFound("Transfer schedule #\(id) not found")
        }
        state.transferSchedules.remove(at: index)
        try persist()
    }

    func addIncomeSchedule(_ submission: IncomeScheduleSubmission) throws -> IncomeSchedule {
        guard state.accounts.contains(where: { $0.id == submission.accountId }) else {
            throw StoreError.notFound("Account #\(submission.accountId) not found")
        }
        let schedule = IncomeSchedule(
            id: state.nextIncomeScheduleId,
            accountId: submission.accountId,
            incomeId: submission.incomeId,
            amount: submission.amount,
            description: submission.description,
            company: submission.company,
            isActive: true,
            isCompleted: false,
            lastExecuted: nil
        )
        state.nextIncomeScheduleId += 1
        state.incomeSchedules.append(schedule)
        try persist()
        return schedule
    }

    func executeIncomeSchedule(id: Int) throws -> MessageResponse {
        guard let index = state.incomeSchedules.firstIndex(where: { $0.id == id }) else {
            throw StoreError.notFound("Income schedule #\(id) not found")
        }
        var schedule = state.incomeSchedules[index]
        guard schedule.isActive else {
            throw StoreError.invalidOperation("Income schedule is inactive")
        }
        try applyIncome(schedule: schedule)
        schedule.isCompleted = true
        schedule.lastExecuted = LocalBudgetStore.isoFormatter.string(from: Date())
        state.incomeSchedules[index] = schedule
        try persist()
        return MessageResponse(message: "Income schedule executed")
    }

    func executeAllIncomeSchedules() throws -> IncomeExecutionResponse {
        var executed = 0
        for index in state.incomeSchedules.indices {
            if state.incomeSchedules[index].isActive && !state.incomeSchedules[index].isCompleted {
                let schedule = state.incomeSchedules[index]
                try applyIncome(schedule: schedule)
                state.incomeSchedules[index].isCompleted = true
                state.incomeSchedules[index].lastExecuted = LocalBudgetStore.isoFormatter.string(from: Date())
                executed += 1
            }
        }
        try persist()
        return IncomeExecutionResponse(accounts: state.accounts, executed_count: executed)
    }

    func deleteIncomeSchedule(id: Int) throws {
        guard let index = state.incomeSchedules.firstIndex(where: { $0.id == id }) else {
            throw StoreError.notFound("Income schedule #\(id) not found")
        }
        state.incomeSchedules.remove(at: index)
        try persist()
    }

    func availableTransfers() -> AvailableTransfers {
        var accountTransfers: [AvailableAccountTransfer] = []
        for schedule in state.transferSchedules where schedule.isActive {
            guard let destinationAccount = state.accounts.first(where: { $0.id == schedule.toAccountId }) else { continue }
            let destinationName = schedule.toPotName ?? destinationAccount.name
            let item = AvailableTransferItem(
                id: schedule.id,
                amount: schedule.amount,
                description: schedule.description,
                date: schedule.lastExecuted,
                company: nil,
                type: "transfer_schedule"
            )
            let transfer = AvailableAccountTransfer(
                destinationId: schedule.id,
                destinationType: schedule.toPotName == nil ? "account" : "pot",
                destinationName: destinationName,
                accountName: destinationAccount.name,
                totalAmount: schedule.amount,
                items: [item]
            )
            accountTransfers.append(transfer)
        }

        let potTransfers = accountTransfers
            .filter { $0.destinationType == "pot" }
            .map { transfer in
                AvailablePotTransfer(
                    destinationId: transfer.destinationId,
                    destinationType: "pot",
                    destinationName: transfer.destinationName,
                    accountName: transfer.accountName,
                    totalAmount: transfer.totalAmount,
                    items: AvailablePotTransferItems(
                        directDebits: transfer.items,
                        cardPayments: []
                    )
                )
            }

        return AvailableTransfers(byAccount: accountTransfers, byPot: potTransfers)
    }

    func restoreSample() throws -> ResetResponse {
        state = BudgetState.sample.normalized()
        try persist()
        return ResetResponse(accounts: state.accounts, income_schedules: state.incomeSchedules, transfer_schedules: state.transferSchedules)
    }

    // MARK: - Helpers

    private func updatePotScheduledPayment(accountIndex: Int, potName: String, mutate: (inout [ScheduledPayment]) -> Void) throws {
        var account = state.accounts[accountIndex]
        guard var pots = account.pots, let potIndex = pots.firstIndex(where: { $0.name == potName }) else {
            throw StoreError.notFound("Pot \(potName) not found")
        }
        var payments = pots[potIndex].scheduled_payments ?? []
        mutate(&payments)
        pots[potIndex].scheduled_payments = payments
        account.pots = pots
        state.accounts[accountIndex] = account
    }

    private func applyTransfer(_ schedule: TransferSchedule) throws {
        if let fromAccountId = schedule.fromAccountId {
            try mutateAccount(id: fromAccountId) { account in
                if let potName = schedule.fromPotId, !potName.isEmpty {
                    guard var pots = account.pots, let potIndex = pots.firstIndex(where: { $0.name == potName }) else {
                        throw StoreError.notFound("Pot \(potName) not found")
                    }
                    pots[potIndex].balance -= schedule.amount
                    account.pots = pots
                } else {
                    account.balance -= schedule.amount
                }
            }
        }
        try mutateAccount(id: schedule.toAccountId) { account in
            if let potName = schedule.toPotName, !potName.isEmpty {
                guard var pots = account.pots, let potIndex = pots.firstIndex(where: { $0.name == potName }) else {
                    throw StoreError.notFound("Pot \(potName) not found")
                }
                pots[potIndex].balance += schedule.amount
                account.pots = pots
            } else {
                account.balance += schedule.amount
            }
        }
    }

    private func applyIncome(schedule: IncomeSchedule) throws {
        try mutateAccount(id: schedule.accountId) { account in
            account.balance += schedule.amount
        }
    }

    private func mutateAccount(id: Int, _ transform: (inout Account) throws -> Void) throws {
        guard let index = state.accounts.firstIndex(where: { $0.id == id }) else {
            throw StoreError.notFound("Account #\(id) not found")
        }
        var account = state.accounts[index]
        try transform(&account)
        state.accounts[index] = account
    }

    private func persist() throws {
        do {
            let directory = persistenceURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try encoder.encode(state)
            try data.write(to: persistenceURL, options: [.atomic])
        } catch {
            throw StoreError.persistence(error)
        }
    }

    private static func makePersistenceURL() -> URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = baseURL.appendingPathComponent("MyBudget", isDirectory: true)
        return directory.appendingPathComponent("budget_state.json")
    }
}

// MARK: - BudgetState Definition

private struct BudgetState: Codable {
    var accounts: [Account]
    var transferSchedules: [TransferSchedule]
    var incomeSchedules: [IncomeSchedule]
    var nextAccountId: Int
    var nextPotId: Int
    var nextIncomeId: Int
    var nextExpenseId: Int
    var nextScheduledPaymentId: Int
    var nextTransferScheduleId: Int
    var nextIncomeScheduleId: Int

    init(
        accounts: [Account],
        transferSchedules: [TransferSchedule],
        incomeSchedules: [IncomeSchedule],
        nextAccountId: Int,
        nextPotId: Int,
        nextIncomeId: Int,
        nextExpenseId: Int,
        nextScheduledPaymentId: Int,
        nextTransferScheduleId: Int,
        nextIncomeScheduleId: Int
    ) {
        self.accounts = accounts
        self.transferSchedules = transferSchedules
        self.incomeSchedules = incomeSchedules
        self.nextAccountId = nextAccountId
        self.nextPotId = nextPotId
        self.nextIncomeId = nextIncomeId
        self.nextExpenseId = nextExpenseId
        self.nextScheduledPaymentId = nextScheduledPaymentId
        self.nextTransferScheduleId = nextTransferScheduleId
        self.nextIncomeScheduleId = nextIncomeScheduleId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        transferSchedules = try container.decodeIfPresent([TransferSchedule].self, forKey: .transferSchedules) ?? []
        incomeSchedules = try container.decodeIfPresent([IncomeSchedule].self, forKey: .incomeSchedules) ?? []
        nextAccountId = try container.decodeIfPresent(Int.self, forKey: .nextAccountId) ?? 1
        nextPotId = try container.decodeIfPresent(Int.self, forKey: .nextPotId) ?? 1
        nextIncomeId = try container.decodeIfPresent(Int.self, forKey: .nextIncomeId) ?? 1
        nextExpenseId = try container.decodeIfPresent(Int.self, forKey: .nextExpenseId) ?? 1
        nextScheduledPaymentId = try container.decodeIfPresent(Int.self, forKey: .nextScheduledPaymentId) ?? 1
        nextTransferScheduleId = try container.decodeIfPresent(Int.self, forKey: .nextTransferScheduleId) ?? 1
        nextIncomeScheduleId = try container.decodeIfPresent(Int.self, forKey: .nextIncomeScheduleId) ?? 1
    }

    func normalized() -> BudgetState {
        var normalizedState = self
        let accountMax = accounts.map(\.id).max() ?? 0
        normalizedState.nextAccountId = max(nextAccountId, accountMax + 1)

        let potMax = accounts.compactMap { $0.pots?.map(\.id).max() }.max() ?? 0
        normalizedState.nextPotId = max(nextPotId, potMax + 1)

        let incomeMax = accounts.compactMap { $0.incomes?.map(\.id).max() }.max() ?? 0
        normalizedState.nextIncomeId = max(nextIncomeId, incomeMax + 1)

        let expenseMax = accounts.compactMap { $0.expenses?.map(\.id).max() }.max() ?? 0
        normalizedState.nextExpenseId = max(nextExpenseId, expenseMax + 1)

        let scheduledAccountMax = accounts.compactMap { $0.scheduled_payments?.map(\.id).max() }.max() ?? 0
        let scheduledPotMax = accounts
            .compactMap { $0.pots?.compactMap { $0.scheduled_payments?.map(\.id).max() }.max() }
            .max() ?? 0
        let scheduledMax = max(scheduledAccountMax, scheduledPotMax)
        normalizedState.nextScheduledPaymentId = max(nextScheduledPaymentId, scheduledMax + 1)

        let transferMax = transferSchedules.map(\.id).max() ?? 0
        normalizedState.nextTransferScheduleId = max(nextTransferScheduleId, transferMax + 1)

        let incomeScheduleMax = incomeSchedules.map(\.id).max() ?? 0
        normalizedState.nextIncomeScheduleId = max(nextIncomeScheduleId, incomeScheduleMax + 1)

        return normalizedState
    }

    static var sample: BudgetState {
        let salaryDate = "2024-03-25T09:00:00Z"
        let freelanceDate = "2024-03-10T14:00:00Z"
        let groceryDate = "2024-03-12T18:30:00Z"
        let commuteDate = "2024-03-05T07:30:00Z"

        let electricPayment = ScheduledPayment(
            id: 1,
            name: "Electric", amount: 92.5, date: "15", company: "City Energy", type: "direct_debit", isCompleted: false, lastExecuted: nil
        )
        let waterPayment = ScheduledPayment(
            id: 2,
            name: "Water", amount: 24.2, date: "2", company: "Pure Water", type: "direct_debit", isCompleted: false, lastExecuted: nil
        )
        let rentPayment = ScheduledPayment(
            id: 3,
            name: "Rent", amount: 1280, date: "1", company: "Maple Estates", type: "standing_order", isCompleted: false, lastExecuted: nil
        )

        let groceriesPot = Pot(id: 1, name: "Groceries", balance: 320, excludeFromReset: false, scheduled_payments: [electricPayment, waterPayment])
        let travelPot = Pot(id: 2, name: "Travel", balance: 180, excludeFromReset: false, scheduled_payments: nil)
        let renovationPot = Pot(id: 3, name: "Renovation", balance: 640, excludeFromReset: false, scheduled_payments: nil)
        let vacationPot = Pot(id: 4, name: "Vacation", balance: 850, excludeFromReset: true, scheduled_payments: nil)

        let salaryIncome = Income(id: 1, amount: 3200, description: "Monthly Salary", company: "Northwind", date: salaryDate)
        let freelanceIncome = Income(id: 2, amount: 540, description: "Freelance Design", company: "Contoso", date: freelanceDate)
        let groceryExpense = Expense(id: 1, amount: 145.6, description: "Supermarket", date: groceryDate)
        let commuteExpense = Expense(id: 2, amount: 48.9, description: "Transit Pass", date: commuteDate)

        let personalAccount = Account(
            id: 1,
            name: "Everyday Checking",
            balance: 1850,
            type: "current",
            accountType: "personal",
            credit_limit: nil,
            excludeFromReset: false,
            pots: [groceriesPot, travelPot],
            scheduled_payments: [rentPayment],
            incomes: [salaryIncome, freelanceIncome],
            expenses: [groceryExpense, commuteExpense]
        )

        let householdAccount = Account(
            id: 2,
            name: "Shared Household",
            balance: 2400,
            type: "current",
            accountType: "joint",
            credit_limit: nil,
            excludeFromReset: false,
            pots: [renovationPot],
            scheduled_payments: nil,
            incomes: nil,
            expenses: nil
        )

        let savingsAccount = Account(
            id: 3,
            name: "Future Savings",
            balance: 5400,
            type: "savings",
            accountType: "personal",
            credit_limit: nil,
            excludeFromReset: true,
            pots: [vacationPot],
            scheduled_payments: nil,
            incomes: nil,
            expenses: nil
        )

        let transferOne = TransferSchedule(
            id: 1,
            fromAccountId: 1,
            fromPotId: nil,
            toAccountId: 2,
            toPotName: "Renovation",
            amount: 250,
            description: "Monthly renovation fund",
            isActive: true,
            isCompleted: false,
            items: nil,
            isDirectPotTransfer: true,
            lastExecuted: nil
        )

        let transferTwo = TransferSchedule(
            id: 2,
            fromAccountId: 1,
            fromPotId: "Groceries",
            toAccountId: 3,
            toPotName: "Vacation",
            amount: 75,
            description: "Leftover groceries sweep",
            isActive: true,
            isCompleted: false,
            items: nil,
            isDirectPotTransfer: true,
            lastExecuted: nil
        )

        let incomeSchedule = IncomeSchedule(
            id: 1,
            accountId: 1,
            incomeId: 1,
            amount: 3200,
            description: "Monthly salary",
            company: "Northwind",
            isActive: true,
            isCompleted: false,
            lastExecuted: nil
        )

        return BudgetState(
            accounts: [personalAccount, householdAccount, savingsAccount],
            transferSchedules: [transferOne, transferTwo],
            incomeSchedules: [incomeSchedule],
            nextAccountId: 4,
            nextPotId: 5,
            nextIncomeId: 3,
            nextExpenseId: 3,
            nextScheduledPaymentId: 4,
            nextTransferScheduleId: 3,
            nextIncomeScheduleId: 2
        )
    }
}
