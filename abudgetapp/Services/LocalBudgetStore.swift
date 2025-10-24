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
            // Start with an empty state when no persisted data exists.
            self.state = BudgetState.empty
            // Avoid persisting during actor initialization to satisfy Swift 6 isolation rules.
        }
    }

    // MARK: - Public API

    func currentAccounts() -> [Account] {
        state.accounts
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
            expenses: [],
            transactions: []
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
            expenses: existing.expenses,
            transactions: existing.transactions
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

    func updateIncome(accountId: Int, incomeId: Int, submission: IncomeSubmission) throws -> Income {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var incomes = account.incomes, let incomeIndex = incomes.firstIndex(where: { $0.id == incomeId }) else {
            throw StoreError.notFound("Income #\(incomeId) not found")
        }
        let old = incomes[incomeIndex]
        let updated = Income(
            id: old.id,
            amount: submission.amount,
            description: submission.description,
            company: submission.company,
            date: submission.date ?? old.date
        )
        incomes[incomeIndex] = updated
        account.incomes = incomes
        // Adjust account balance by the delta
        let delta = submission.amount - old.amount
        account.balance += delta
        state.accounts[index] = account
        try persist()
        return updated
    }

    func addTransaction(accountId: Int, submission: TransactionSubmission) throws -> TransactionEntry {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        var transactions = account.transactions ?? []
        let entry = TransactionEntry(
            id: state.nextTransactionId,
            amount: submission.amount,
            description: submission.description,
            date: submission.date,
            merchant: submission.merchant,
            isCredit: submission.isCredit
        )
        state.nextTransactionId += 1
        transactions.append(entry)
        account.transactions = transactions
        account.balance += submission.isCredit ? submission.amount : -submission.amount
        state.accounts[index] = account
        try persist()
        return entry
    }

    func updateTransaction(accountId: Int, transactionId: Int, submission: TransactionSubmission) throws -> TransactionEntry {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var entries = account.transactions, let entryIndex = entries.firstIndex(where: { $0.id == transactionId }) else {
            throw StoreError.notFound("Transaction #\(transactionId) not found")
        }
        let existing = entries[entryIndex]
        let oldSigned = existing.isCredit ? existing.amount : -existing.amount
        let newSigned = submission.isCredit ? submission.amount : -submission.amount
        let updated = TransactionEntry(
            id: existing.id,
            amount: submission.amount,
            description: submission.description,
            date: submission.date,
            merchant: submission.merchant,
            isCredit: submission.isCredit
        )
        entries[entryIndex] = updated
        account.transactions = entries
        account.balance += newSigned - oldSigned
        state.accounts[index] = account
        try persist()
        return updated
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

    func updateExpense(accountId: Int, expenseId: Int, submission: ExpenseSubmission) throws -> Expense {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var expenses = account.expenses, let expenseIndex = expenses.firstIndex(where: { $0.id == expenseId }) else {
            throw StoreError.notFound("Expense #\(expenseId) not found")
        }
        let old = expenses[expenseIndex]
        let updated = Expense(
            id: old.id,
            amount: submission.amount,
            description: submission.description,
            date: submission.date ?? old.date
        )
        expenses[expenseIndex] = updated
        account.expenses = expenses
        // Remove old effect, then apply new
        account.balance += old.amount
        account.balance -= submission.amount
        state.accounts[index] = account
        try persist()
        return updated
    }

    func deleteTransaction(accountId: Int, transactionId: Int) throws {
        guard let index = state.accounts.firstIndex(where: { $0.id == accountId }) else {
            throw StoreError.notFound("Account #\(accountId) not found")
        }
        var account = state.accounts[index]
        guard var entries = account.transactions, let entryIndex = entries.firstIndex(where: { $0.id == transactionId }) else {
            throw StoreError.notFound("Transaction #\(transactionId) not found")
        }
        let entry = entries.remove(at: entryIndex)
        account.transactions = entries
        let signed = entry.isCredit ? entry.amount : -entry.amount
        account.balance -= signed
        state.accounts[index] = account
        try persist()
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
        // Allow schedules to be executed again after a reset
        for idx in state.incomeSchedules.indices {
            state.incomeSchedules[idx].isCompleted = false
            state.incomeSchedules[idx].lastExecuted = nil
        }
        // Track last reset timestamp
        state.lastResetAt = LocalBudgetStore.isoFormatter.string(from: Date())
        try persist()
        return ResetResponse(accounts: state.accounts, income_schedules: state.incomeSchedules)
    }

    func lastResetTimestamp() -> String? {
        state.lastResetAt
    }

    func savingsAndInvestments() -> [Account] {
        state.accounts.filter { account in
            let type = account.type.lowercased()
            let category = account.accountType?.lowercased() ?? ""
            return type == "savings" || type == "investment" || category == "investment"
        }
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
    var incomeSchedules: [IncomeSchedule]
    var lastResetAt: String?
    var nextAccountId: Int
    var nextPotId: Int
    var nextIncomeId: Int
    var nextExpenseId: Int
    var nextScheduledPaymentId: Int
    var nextTransactionId: Int
    var nextIncomeScheduleId: Int

    init(
        accounts: [Account],
        incomeSchedules: [IncomeSchedule],
        lastResetAt: String? = nil,
        nextAccountId: Int,
        nextPotId: Int,
        nextIncomeId: Int,
        nextExpenseId: Int,
        nextScheduledPaymentId: Int,
        nextTransactionId: Int,
        nextIncomeScheduleId: Int
    ) {
        self.accounts = accounts
        self.incomeSchedules = incomeSchedules
        self.lastResetAt = lastResetAt
        self.nextAccountId = nextAccountId
        self.nextPotId = nextPotId
        self.nextIncomeId = nextIncomeId
        self.nextExpenseId = nextExpenseId
        self.nextScheduledPaymentId = nextScheduledPaymentId
        self.nextTransactionId = nextTransactionId
        self.nextIncomeScheduleId = nextIncomeScheduleId
    }

    private enum CodingKeys: String, CodingKey {
        case accounts
        case incomeSchedules = "income_schedules"
        case lastResetAt = "last_reset_at"
        case nextAccountId
        case nextPotId
        case nextIncomeId
        case nextExpenseId
        case nextScheduledPaymentId
        case nextTransactionId
        case nextIncomeScheduleId
    }

    private enum LegacyKeys: String, CodingKey {
        case accounts
        case incomeSchedules
        case lastResetAt
        case nextAccountId
        case nextPotId
        case nextIncomeId
        case nextExpenseId
        case nextScheduledPaymentId
        case nextTransactionId
        case nextIncomeScheduleId
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
            incomeSchedules = try container.decodeIfPresent([IncomeSchedule].self, forKey: .incomeSchedules) ?? []
            lastResetAt = try container.decodeIfPresent(String.self, forKey: .lastResetAt)
            nextAccountId = try container.decodeIfPresent(Int.self, forKey: .nextAccountId) ?? 1
            nextPotId = try container.decodeIfPresent(Int.self, forKey: .nextPotId) ?? 1
            nextIncomeId = try container.decodeIfPresent(Int.self, forKey: .nextIncomeId) ?? 1
            nextExpenseId = try container.decodeIfPresent(Int.self, forKey: .nextExpenseId) ?? 1
            nextScheduledPaymentId = try container.decodeIfPresent(Int.self, forKey: .nextScheduledPaymentId) ?? 1
            nextTransactionId = try container.decodeIfPresent(Int.self, forKey: .nextTransactionId) ?? 1
            nextIncomeScheduleId = try container.decodeIfPresent(Int.self, forKey: .nextIncomeScheduleId) ?? 1
            return
        }

        let container = try decoder.container(keyedBy: LegacyKeys.self)
        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        incomeSchedules = try container.decodeIfPresent([IncomeSchedule].self, forKey: .incomeSchedules) ?? []
        lastResetAt = try container.decodeIfPresent(String.self, forKey: .lastResetAt)
        nextAccountId = try container.decodeIfPresent(Int.self, forKey: .nextAccountId) ?? 1
        nextPotId = try container.decodeIfPresent(Int.self, forKey: .nextPotId) ?? 1
        nextIncomeId = try container.decodeIfPresent(Int.self, forKey: .nextIncomeId) ?? 1
        nextExpenseId = try container.decodeIfPresent(Int.self, forKey: .nextExpenseId) ?? 1
        nextScheduledPaymentId = try container.decodeIfPresent(Int.self, forKey: .nextScheduledPaymentId) ?? 1
        nextTransactionId = try container.decodeIfPresent(Int.self, forKey: .nextTransactionId) ?? 1
        nextIncomeScheduleId = try container.decodeIfPresent(Int.self, forKey: .nextIncomeScheduleId) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(incomeSchedules, forKey: .incomeSchedules)
        try container.encodeIfPresent(lastResetAt, forKey: .lastResetAt)
        try container.encode(nextAccountId, forKey: .nextAccountId)
        try container.encode(nextPotId, forKey: .nextPotId)
        try container.encode(nextIncomeId, forKey: .nextIncomeId)
        try container.encode(nextExpenseId, forKey: .nextExpenseId)
        try container.encode(nextScheduledPaymentId, forKey: .nextScheduledPaymentId)
        try container.encode(nextTransactionId, forKey: .nextTransactionId)
        try container.encode(nextIncomeScheduleId, forKey: .nextIncomeScheduleId)
    }

    static var empty: BudgetState {
        BudgetState(
            accounts: [],
            incomeSchedules: [],
            lastResetAt: nil,
            nextAccountId: 1,
            nextPotId: 1,
            nextIncomeId: 1,
            nextExpenseId: 1,
            nextScheduledPaymentId: 1,
            nextTransactionId: 1,
            nextIncomeScheduleId: 1
        )
    }

    static var sample: BudgetState {
        let salaryDate = "2024-03-25T09:00:00Z"
        let freelanceDate = "2024-03-10T14:00:00Z"
        let groceryDate = "2024-03-12T18:30:00Z"
        let commuteDate = "2024-03-05T07:30:00Z"
        let refundDate = "2024-03-15T12:00:00Z"

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

        let groceryTransaction = TransactionEntry(
            id: 1,
            amount: 45.2,
            description: "Weekly Groceries",
            date: groceryDate,
            merchant: "Supermart",
            isCredit: false
        )
        let refundTransaction = TransactionEntry(
            id: 2,
            amount: 30,
            description: "Reimbursement",
            date: refundDate,
            merchant: "Employer",
            isCredit: true
        )

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
            expenses: [groceryExpense, commuteExpense],
            transactions: [groceryTransaction, refundTransaction]
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
            expenses: nil,
            transactions: []
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
            expenses: nil,
            transactions: []
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
            incomeSchedules: [incomeSchedule],
            nextAccountId: 4,
            nextPotId: 5,
            nextIncomeId: 3,
            nextExpenseId: 3,
            nextScheduledPaymentId: 4,
            nextTransactionId: 3,
            nextIncomeScheduleId: 2
        )
    }

    func normalized() -> BudgetState {
        var normalizedState = self
        let accountMax = accounts.map(\.id).max() ?? 0
        let potMax = accounts.flatMap { $0.pots ?? [] }.map(\.id).max() ?? 0
        let incomeMax = accounts.flatMap { $0.incomes ?? [] }.map(\.id).max() ?? 0
        let expenseMax = accounts.flatMap { $0.expenses ?? [] }.map(\.id).max() ?? 0
        let scheduledMax = accounts.flatMap { $0.scheduled_payments ?? [] }.map(\.id).max() ?? 0
        let transactionMax = accounts.flatMap { $0.transactions ?? [] }.map(\.id).max() ?? 0
        let incomeScheduleMax = incomeSchedules.map(\.id).max() ?? 0

        normalizedState.nextAccountId = max(nextAccountId, accountMax + 1)
        normalizedState.nextPotId = max(nextPotId, potMax + 1)
        normalizedState.nextIncomeId = max(nextIncomeId, incomeMax + 1)
        normalizedState.nextExpenseId = max(nextExpenseId, expenseMax + 1)
        normalizedState.nextScheduledPaymentId = max(nextScheduledPaymentId, scheduledMax + 1)
        normalizedState.nextTransactionId = max(nextTransactionId, transactionMax + 1)
        normalizedState.nextIncomeScheduleId = max(nextIncomeScheduleId, incomeScheduleMax + 1)
        return normalizedState
    }
}
