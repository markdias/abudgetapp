import Foundation

@MainActor
final class DiagnosticsStore: ObservableObject {
    enum StepStatus {
        case pending
        case running
        case success(String?)
        case failure(String)
    }

    struct DiagnosticStep: Identifiable {
        let id = UUID()
        let name: String
        var status: StepStatus = .pending
        var duration: TimeInterval?
    }

    @Published private(set) var steps: [DiagnosticStep] = []
    @Published var isRunning = false

    private let store: LocalBudgetStore
    private weak var accountsStore: AccountsStore?
    private static let stepNames: [String] = [
        "Fetch Accounts",
        "Add Account",
        "Update Account",
        "Add Pot",
        "Update Pot",
        "Toggle Pot Exclusion",
        "Add Income",
        "Schedule Income",
        "Execute Income Schedule",
        "Add Target",
        "Add Transaction",
        "Add Scheduled Payment",
        "Add Transfer Schedule",
        "Execute Transfer Schedule",
        "Apply Monthly Reduction",
        "Delete Transfer Schedule",
        "Delete Scheduled Payment",
        "Delete Transaction",
        "Delete Target",
        "Delete Income Schedule",
        "Delete Income",
        "Delete Pot",
        "Delete Account",
        "Reset Balances",
        "Reload Accounts"
    ]

    init(store: LocalBudgetStore = .shared, accountsStore: AccountsStore? = nil) {
        self.store = store
        self.accountsStore = accountsStore
        self.steps = DiagnosticsStore.defaultSteps()
    }

    func attachAccountsStore(_ store: AccountsStore) {
        self.accountsStore = store
    }

    func runFullSuite() async {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }

        var updatedSteps = DiagnosticsStore.defaultSteps()
        steps = updatedSteps

        var diagnosticsAccount: Account?
        var diagnosticsPot: Pot?
        var diagnosticsIncome: Income?
        var diagnosticsTransaction: TransactionRecord?
        var diagnosticsTarget: TargetRecord?
        var diagnosticsTransferSchedule: TransferSchedule?
        var diagnosticsIncomeSchedule: IncomeSchedule?
        var diagnosticsScheduledPayment: ScheduledPayment?

        let diagnosticsAccountName = "Diagnostics \(UUID().uuidString.prefix(4))"
        let diagnosticsPotName = "Diagnostics Pot"
        let incomeDescription = "Diagnostics Income"
        let targetName = "Diagnostics Target"
        let transactionName = "Diagnostics Transaction"
        let scheduledPaymentName = "Diagnostics Payment"
        let transferDescription = "Diagnostics Transfer"
        let today = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoTimestamp = isoFormatter.string(from: today)
        let dayOfMonth = String(Calendar.current.component(.day, from: today))

        let operations: [(String, () async throws -> String?)] = [
            ("Fetch Accounts", {
                let accounts = await self.store.currentAccounts()
                return "Found \(accounts.count) accounts"
            }),
            ("Add Account", {
                let submission = AccountSubmission(
                    name: diagnosticsAccountName,
                    balance: 500,
                    type: "current",
                    accountType: "personal"
                )
                let account = try await self.store.addAccount(submission)
                diagnosticsAccount = account
                return "Created account #\(account.id)"
            }),
            ("Update Account", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for update")
                }
                let updated = try await self.store.updateAccount(
                    id: account.id,
                    submission: AccountSubmission(
                        name: "\(diagnosticsAccountName) Updated",
                        balance: account.balance + 25,
                        type: account.type,
                        accountType: account.accountType ?? "personal",
                        credit_limit: account.credit_limit,
                        excludeFromReset: account.excludeFromReset
                    )
                )
                diagnosticsAccount = updated
                return "Updated account balance to £\(String(format: "%.2f", updated.balance))"
            }),
            ("Add Pot", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for pot")
                }
                let pot = try await self.store.addPot(
                    accountId: account.id,
                    submission: PotSubmission(name: diagnosticsPotName, balance: 120)
                )
                diagnosticsPot = pot
                return "Added pot \(pot.name)"
            }),
            ("Update Pot", {
                guard let account = diagnosticsAccount, let pot = diagnosticsPot else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics pot for update")
                }
                let updated = try await self.store.updatePot(
                    accountId: account.id,
                    potId: pot.id,
                    submission: PotSubmission(name: pot.name, balance: 200, excludeFromReset: true)
                )
                diagnosticsPot = updated
                return "Updated pot balance to £\(String(format: "%.2f", updated.balance))"
            }),
            ("Toggle Pot Exclusion", {
                guard let account = diagnosticsAccount, let pot = diagnosticsPot else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics pot for exclusion toggle")
                }
                let excluded = try await self.store.togglePotExclusion(accountId: account.id, potName: pot.name)
                diagnosticsPot?.excludeFromReset = excluded
                return excluded ? "Pot excluded from resets" : "Pot included in resets"
            }),
            ("Add Income", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for income")
                }
                let submission = IncomeSubmission(
                    amount: 250,
                    description: incomeDescription,
                    company: "Diagnostics Ltd",
                    date: dayOfMonth,
                    potName: diagnosticsPot?.name
                )
                let income = try await self.store.addIncome(accountId: account.id, submission: submission)
                diagnosticsIncome = income
                return "Recorded income \(income.description)"
            }),
            ("Schedule Income", {
                guard let account = diagnosticsAccount, let income = diagnosticsIncome else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics income for schedule")
                }
                let schedule = try await self.store.addIncomeSchedule(
                    IncomeScheduleSubmission(
                        accountId: account.id,
                        incomeId: income.id,
                        amount: income.amount,
                        description: income.description,
                        company: income.company
                    )
                )
                diagnosticsIncomeSchedule = schedule
                return "Scheduled income \(income.description)"
            }),
            ("Execute Income Schedule", {
                guard let schedule = diagnosticsIncomeSchedule else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics income schedule for execution")
                }
                let response = try await self.store.executeIncomeSchedule(id: schedule.id)
                return response.message
            }),
            ("Add Target", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for target")
                }
                let target = try await self.store.addTarget(
                    TargetSubmission(name: targetName, amount: 75, date: dayOfMonth, accountId: account.id)
                )
                diagnosticsTarget = target
                return "Created target \(target.name)"
            }),
            ("Add Transaction", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for transaction")
                }
                let transaction = try await self.store.addTransaction(
                    TransactionSubmission(
                        name: transactionName,
                        vendor: "Diagnostics Vendor",
                        amount: 42,
                        date: isoTimestamp,
                        fromAccountId: nil,
                        toAccountId: account.id,
                        toPotName: diagnosticsPot?.name,
                        paymentType: "card",
                        linkedCreditAccountId: nil
                    )
                )
                diagnosticsTransaction = transaction
                return "Logged transaction \(transaction.name)"
            }),
            ("Add Scheduled Payment", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for scheduled payment")
                }
                let submission = ScheduledPaymentSubmission(
                    name: scheduledPaymentName,
                    amount: 30,
                    date: isoTimestamp,
                    company: "Diagnostics Utilities",
                    type: "direct_debit"
                )
                let payment = try await self.store.addScheduledPayment(
                    accountId: account.id,
                    potName: diagnosticsPot?.name,
                    submission: submission
                )
                diagnosticsScheduledPayment = payment
                return "Added scheduled payment \(payment.name)"
            }),
            ("Add Transfer Schedule", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for transfer schedule")
                }
                let schedule = try await self.store.addTransferSchedule(
                    TransferScheduleSubmission(
                        fromAccountId: account.id,
                        fromPotName: nil,
                        toAccountId: account.id,
                        toPotName: diagnosticsPot?.name,
                        amount: 20,
                        description: transferDescription
                    )
                )
                diagnosticsTransferSchedule = schedule
                return "Queued transfer schedule"
            }),
            ("Execute Transfer Schedule", {
                guard let schedule = diagnosticsTransferSchedule else {
                    throw BudgetDataError.invalidOperation("Missing transfer schedule for execution")
                }
                let response = try await self.store.executeTransferSchedule(id: schedule.id)
                diagnosticsTransferSchedule = await self.store.currentTransferSchedules().first(where: { $0.id == schedule.id })
                return response.message
            }),
            ("Apply Monthly Reduction", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for reduction")
                }
                let beforeLogs = await self.store.currentBalanceReductionLogs()
                let priorCount = beforeLogs.count

                let updatedAccounts = try await self.store.applyMonthlyReduction(on: Date())
                diagnosticsAccount = updatedAccounts.first(where: { $0.id == account.id }) ?? diagnosticsAccount

                let afterLogs = await self.store.currentBalanceReductionLogs()
                let delta = afterLogs.count - priorCount
                guard delta > 0 else {
                    throw BudgetDataError.invalidOperation("Monthly reduction did not record any history entries")
                }
                let latestLog = afterLogs.sorted { $0.timestamp > $1.timestamp }.first
                let totalReduced = afterLogs.suffix(delta).reduce(0.0) { $0 + max($1.reductionAmount, 0) }
                let amountText = String(format: "%.2f", totalReduced)
                let monthText = latestLog?.monthKey ?? "current month"
                return "Logged \(delta) reduction run(s) for \(monthText) (−£\(amountText))."
            }),
            ("Delete Transfer Schedule", {
                guard let schedule = diagnosticsTransferSchedule else {
                    throw BudgetDataError.invalidOperation("Missing transfer schedule for deletion")
                }
                try await self.store.deleteTransferSchedule(id: schedule.id)
                diagnosticsTransferSchedule = nil
                return "Removed transfer schedule"
            }),
            ("Delete Scheduled Payment", {
                guard let account = diagnosticsAccount, let payment = diagnosticsScheduledPayment else {
                    throw BudgetDataError.invalidOperation("Missing scheduled payment for deletion")
                }
                try await self.store.deleteScheduledPayment(
                    accountId: account.id,
                    paymentName: payment.name,
                    paymentDate: payment.date,
                    potName: diagnosticsPot?.name
                )
                diagnosticsScheduledPayment = nil
                return "Deleted scheduled payment"
            }),
            ("Delete Transaction", {
                guard let transaction = diagnosticsTransaction else {
                    throw BudgetDataError.invalidOperation("Missing transaction for deletion")
                }
                try await self.store.deleteTransaction(id: transaction.id)
                diagnosticsTransaction = nil
                return "Deleted transaction"
            }),
            ("Delete Target", {
                guard let target = diagnosticsTarget else {
                    throw BudgetDataError.invalidOperation("Missing target for deletion")
                }
                try await self.store.deleteTarget(id: target.id)
                diagnosticsTarget = nil
                return "Deleted target"
            }),
            ("Delete Income Schedule", {
                guard let schedule = diagnosticsIncomeSchedule else {
                    throw BudgetDataError.invalidOperation("Missing income schedule for deletion")
                }
                try await self.store.deleteIncomeSchedule(id: schedule.id)
                diagnosticsIncomeSchedule = nil
                return "Deleted income schedule"
            }),
            ("Delete Income", {
                guard let account = diagnosticsAccount, let income = diagnosticsIncome else {
                    throw BudgetDataError.invalidOperation("Missing income for deletion")
                }
                try await self.store.deleteIncome(accountId: account.id, incomeId: income.id)
                diagnosticsIncome = nil
                return "Deleted income record"
            }),
            ("Delete Pot", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for pot removal")
                }
                try await self.store.deletePot(accountName: account.name, potName: diagnosticsPotName)
                diagnosticsPot = nil
                return "Removed diagnostics pot"
            }),
            ("Delete Account", {
                guard let account = diagnosticsAccount else {
                    throw BudgetDataError.invalidOperation("Missing diagnostics account for deletion")
                }
                try await self.store.deleteAccount(id: account.id)
                diagnosticsAccount = nil
                return "Deleted diagnostics account"
            }),
            ("Reset Balances", {
                let reset = try await self.store.resetBalances()
                self.accountsStore?.applyAccounts(reset.accounts)
                let remainingLogs = await self.store.currentBalanceReductionLogs()
                guard remainingLogs.isEmpty else {
                    throw BudgetDataError.invalidOperation("Reduction history not cleared by reset")
                }
                return "Reset \(reset.accounts.count) accounts and cleared reduction history"
            }),
            ("Reload Accounts", {
                await self.accountsStore?.loadAccounts()
                return "Accounts refreshed"
            })
        ]

        for index in operations.indices {
            let (_, operation) = operations[index]
            updatedSteps[index].status = .running
            steps = updatedSteps
            let start = Date()
            do {
                let message = try await operation()
                updatedSteps[index].status = .success(message)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            } catch let error as LocalBudgetStore.StoreError {
                updatedSteps[index].status = .failure(error.asBudgetDataError.localizedDescription)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            } catch let dataError as BudgetDataError {
                updatedSteps[index].status = .failure(dataError.localizedDescription)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            } catch {
                let fallback = BudgetDataError.unknown(error)
                updatedSteps[index].status = .failure(fallback.localizedDescription)
                updatedSteps[index].duration = Date().timeIntervalSince(start)
            }
            steps = updatedSteps
        }
    }

    private static func defaultSteps() -> [DiagnosticStep] {
        stepNames.map { DiagnosticStep(name: $0) }
    }
}
