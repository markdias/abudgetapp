import Foundation

@MainActor
final class ActivityStore: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case income = "Income"
        case expenses = "Expenses"
        case transfers = "Transfers"
        case scheduled = "Scheduled"

        var id: String { rawValue }

        var category: ActivityCategory? {
            switch self {
            case .all: return nil
            case .income: return .income
            case .expenses: return .expense
            case .transfers: return .transfer
            case .scheduled: return .scheduledPayment
            }
        }
    }

    @Published private(set) var activities: [ActivityItem] = [] {
        didSet { applyFilter() }
    }
    @Published private(set) var filteredActivities: [ActivityItem] = []
    @Published var filter: Filter = .all {
        didSet { applyFilter() }
    }
    @Published var isMarking: Bool = false {
        didSet {
            if !isMarking { markedIdentifiers.removeAll() }
        }
    }
    @Published private(set) var markedIdentifiers: Set<ActivityItem.ID> = []

    private var accountsObserver: NSObjectProtocol?
    private var currentTransactions: [TransactionRecord] = []

    init(accountsStore: AccountsStore) {
        let items = Self.buildActivities(from: accountsStore.accounts, transactions: accountsStore.transactions)
        self.activities = items
        self.filteredActivities = items
        self.currentTransactions = accountsStore.transactions
        accountsObserver = NotificationCenter.default.addObserver(
            forName: AccountsStore.accountsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let accounts = notification.userInfo?["accounts"] as? [Account] else { return }
            let transactions = notification.userInfo?["transactions"] as? [TransactionRecord]
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let transactions { self.currentTransactions = transactions }
                let items = Self.buildActivities(from: accounts, transactions: self.currentTransactions)
                self.activities = items
                self.applyFilter()
            }
        }
    }

    deinit {
        if let observer = accountsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func toggleMark(for item: ActivityItem) {
        if markedIdentifiers.contains(item.id) {
            markedIdentifiers.remove(item.id)
        } else {
            markedIdentifiers.insert(item.id)
        }
    }

    func markAllFiltered() {
        markedIdentifiers = Set(filteredActivities.map { $0.id })
    }

    func clearMarks() {
        markedIdentifiers.removeAll()
    }

    private nonisolated static func buildActivities(from accounts: [Account], transactions: [TransactionRecord]) -> [ActivityItem] {
        var items: [ActivityItem] = []
        let accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        for account in accounts {
            if let incomes = account.incomes {
                for income in incomes {
                    guard let date = ActivityStore.parse(dateString: income.date) else { continue }
                    let id = "income-\(income.id)"
                    items.append(ActivityItem(
                        id: id,
                        title: income.description,
                        amount: income.amount,
                        date: date,
                        accountName: account.name,
                        potName: income.potName,
                        company: income.company,
                        category: .income,
                        metadata: [
                            "type": "income",
                            "potName": income.potName ?? ""
                        ]
                    ))
                }
            }

            if let expenses = account.expenses {
                for expense in expenses {
                    guard let date = ActivityStore.parse(dateString: expense.date) else { continue }
                    let id = "expense-\(expense.id)"
                    var metadata: [String: String] = ["type": "expense"]
                    if let toId = expense.toAccountId, let toAccount = accountMap[toId] {
                        metadata["toAccountId"] = String(toId)
                        metadata["toAccountName"] = toAccount.name
                    }
                    if let potName = expense.toPotName {
                        metadata["toPotName"] = potName
                    }
                    items.append(ActivityItem(
                        id: id,
                        title: expense.description,
                        amount: expense.amount,
                        date: date,
                        accountName: account.name,
                        potName: expense.toPotName,
                        company: nil,
                        category: .expense,
                        metadata: metadata
                    ))
                }
            }

            if let scheduled = account.scheduled_payments {
                for payment in scheduled {
                    guard let date = ActivityStore.parse(dateString: payment.date) else { continue }
                    let id = "scheduled-\(account.id)-\(payment.id)"
                    items.append(ActivityItem(
                        id: id,
                        title: payment.name,
                        amount: payment.amount,
                        date: date,
                        accountName: account.name,
                        potName: nil,
                        company: payment.company,
                        category: .scheduledPayment,
                        metadata: [
                            "paymentType": payment.type ?? "",
                            "isCompleted": String(payment.isCompleted ?? false)
                        ]
                    ))
                }
            }

            if let pots = account.pots {
                for pot in pots {
                    if let payments = pot.scheduled_payments {
                        for payment in payments {
                            guard let date = ActivityStore.parse(dateString: payment.date) else { continue }
                            let id = "scheduled-pot-\(account.id)-\(pot.id)-\(payment.id)"
                            items.append(ActivityItem(
                                id: id,
                                title: payment.name,
                                amount: payment.amount,
                                date: date,
                                accountName: account.name,
                                potName: pot.name,
                                company: payment.company,
                                category: .scheduledPayment,
                                metadata: [
                                    "paymentType": payment.type ?? "",
                                    "isCompleted": String(payment.isCompleted ?? false)
                                ]
                            ))
                        }
                    }
                }
            }
        }

        for transaction in transactions {
            guard let date = ActivityStore.parse(dateString: transaction.date) else { continue }
            let counterpartyOut = accountMap[transaction.toAccountId]?.name ?? ""
            let counterpartyIn = accountMap[transaction.fromAccountId]?.name ?? ""

            if let fromAccount = accountMap[transaction.fromAccountId] {
                let metadata: [String: String] = [
                    "type": "transaction",
                    "transactionId": String(transaction.id),
                    "direction": "out",
                    "counterparty": counterpartyOut,
                    "potName": transaction.toPotName ?? ""
                ]
                items.append(ActivityItem(
                    id: "transaction-\(transaction.id)-out",
                    title: transaction.name,
                    amount: transaction.amount,
                    date: date,
                    accountName: fromAccount.name,
                    potName: nil,
                    company: transaction.vendor,
                    category: .transfer,
                    metadata: metadata
                ))
            }

            if let toAccount = accountMap[transaction.toAccountId] {
                let metadata: [String: String] = [
                    "type": "transaction",
                    "transactionId": String(transaction.id),
                    "direction": "in",
                    "counterparty": counterpartyIn,
                    "potName": transaction.toPotName ?? ""
                ]
                items.append(ActivityItem(
                    id: "transaction-\(transaction.id)-in",
                    title: transaction.name,
                    amount: transaction.amount,
                    date: date,
                    accountName: toAccount.name,
                    potName: transaction.toPotName,
                    company: transaction.vendor,
                    category: .transfer,
                    metadata: metadata
                ))
            }
        }

        items.sort { $0.date > $1.date }
        return items
    }

    private func applyFilter() {
        if let category = filter.category {
            filteredActivities = activities.filter { $0.category == category }
        } else {
            filteredActivities = activities
        }
    }

    private nonisolated static func parse(dateString: String) -> Date? {
        if let isoDate = ISO8601DateFormatter().date(from: dateString) {
            return isoDate
        }
        if let day = Int(dateString) {
            var components = Calendar.current.dateComponents([.year, .month], from: Date())
            components.day = day
            return Calendar.current.date(from: components)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}
