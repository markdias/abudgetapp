import Foundation

@MainActor
final class ActivityStore: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case scheduled = "Scheduled"
        case expenses = "Expenses"
        case income = "Income"

        var id: String { rawValue }

        var category: ActivityCategory? {
            switch self {
            case .all: return nil
            case .scheduled: return .scheduledPayment
            case .expenses: return .expense
            case .income: return .income
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

    private let accountsStore: AccountsStore
    private var transferSchedules: [TransferSchedule]
    private var accountsObserver: NSObjectProtocol?
    private var transferObserver: NSObjectProtocol?

    init(accountsStore: AccountsStore, transferStore: TransferSchedulesStore? = nil) {
        self.accountsStore = accountsStore
        self.transferSchedules = transferStore?.schedules ?? []
        let items = Self.buildActivities(from: accountsStore.accounts, transferSchedules: self.transferSchedules)
        self.activities = items
        self.filteredActivities = items
        accountsObserver = NotificationCenter.default.addObserver(
            forName: AccountsStore.accountsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let accounts = notification.userInfo?["accounts"] as? [Account] else { return }
            let items = Self.buildActivities(from: accounts, transferSchedules: self.transferSchedules)
            Task { @MainActor in
                self.activities = items
                self.applyFilter()
            }
        }

        if let transferStore = transferStore {
            transferObserver = NotificationCenter.default.addObserver(
                forName: TransferSchedulesStore.schedulesDidChangeNotification,
                object: transferStore,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                let schedules = notification.userInfo?["schedules"] as? [TransferSchedule] ?? []
                self.transferSchedules = schedules
                let items = Self.buildActivities(from: self.accountsStore.accounts, transferSchedules: schedules)
                self.activities = items
                self.applyFilter()
            }
        }
    }

    deinit {
        if let observer = accountsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = transferObserver {
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

    private nonisolated static func buildActivities(from accounts: [Account], transferSchedules: [TransferSchedule]) -> [ActivityItem] {
        var items: [ActivityItem] = []
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
                        potName: nil,
                        company: income.company,
                        category: .income,
                        metadata: ["type": "income"]
                    ))
                }
            }

            if let expenses = account.expenses {
                for expense in expenses {
                    guard let date = ActivityStore.parse(dateString: expense.date) else { continue }
                    let id = "expense-\(expense.id)"
                    items.append(ActivityItem(
                        id: id,
                        title: expense.description,
                        amount: expense.amount,
                        date: date,
                        accountName: account.name,
                        potName: nil,
                        company: nil,
                        category: .expense,
                        metadata: ["type": "expense"]
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

        for schedule in transferSchedules {
            guard let account = accounts.first(where: { $0.id == schedule.toAccountId }) else { continue }
            if let scheduleItems = schedule.items {
                for item in scheduleItems {
                    guard let normalizedType = item.type?.lowercased(), normalizedType == "expense" else { continue }
                    let parsedDate = (item.date.flatMap { ActivityStore.parse(dateString: $0) })
                        ?? (schedule.lastExecuted.flatMap { ActivityStore.parse(dateString: $0) })
                        ?? Date()
                    let identifier: String
                    if let itemId = item.id {
                        identifier = "transfer-expense-\(schedule.id)-\(itemId)"
                    } else {
                        identifier = "transfer-expense-\(schedule.id)-\(UUID().uuidString)"
                    }
                    items.append(ActivityItem(
                        id: identifier,
                        title: item.description,
                        amount: item.amount,
                        date: parsedDate,
                        accountName: account.name,
                        potName: schedule.toPotName,
                        company: item.company,
                        category: .expense,
                        metadata: [
                            "type": normalizedType,
                            "source": "transferSchedule",
                            "scheduleId": String(schedule.id)
                        ]
                    ))
                }
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
