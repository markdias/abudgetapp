import Foundation

public enum ActivityCategory: String, CaseIterable, Codable {
    case scheduledPayment = "Scheduled"
    case expense = "Expense"
    case income = "Income"
    case transaction = "Transaction"

    public var colorName: String {
        switch self {
        case .scheduledPayment: return "Purple"
        case .expense: return "Red"
        case .income: return "Green"
        case .transaction: return "Blue"
        }
    }
}

public struct ActivityItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let amount: Double
    public let date: Date
    public let accountName: String
    public let potName: String?
    public let company: String?
    public let category: ActivityCategory
    public let metadata: [String: String]

    public init(id: String = UUID().uuidString,
                title: String,
                amount: Double,
                date: Date,
                accountName: String,
                potName: String?,
                company: String?,
                category: ActivityCategory,
                metadata: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.accountName = accountName
        self.potName = potName
        self.company = company
        self.category = category
        self.metadata = metadata
    }

    public var formattedAmount: String {
        let prefix: String
        switch category {
        case .income:
            prefix = "+"
        case .transaction:
            prefix = metadata["direction"] == "credit" ? "+" : "-"
        default:
            prefix = "-"
        }
        return "\(prefix)£\(String(format: "%.2f", amount))"
    }
}
