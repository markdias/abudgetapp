import Foundation

struct TransferScheduleItem: Identifiable, Hashable {
    struct Context: Hashable {
        let expenseId: Int
        let description: String
        let amount: Double
        let date: String
    }

    let id: String
    let fromAccountId: Int
    let fromAccountName: String
    let toAccountId: Int
    let toAccountName: String
    let toPotName: String?
    let amount: Double
    let contexts: [Context]

    init(fromAccountId: Int,
         fromAccountName: String,
         toAccountId: Int,
         toAccountName: String,
         toPotName: String?,
         amount: Double,
         contexts: [Context]) {
        self.fromAccountId = fromAccountId
        self.fromAccountName = fromAccountName
        self.toAccountId = toAccountId
        self.toAccountName = toAccountName
        self.toPotName = toPotName
        self.amount = amount
        self.contexts = contexts.sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
        let potComponent = toPotName?.isEmpty == false ? toPotName! : "account"
        self.id = "\(fromAccountId)->\(toAccountId)-\(potComponent.lowercased())"
    }

    var destinationDisplayName: String {
        if let potName = toPotName, !potName.isEmpty {
            return potName
        }
        return toAccountName
    }

    var destinationSubtitle: String? {
        if let potName = toPotName, !potName.isEmpty {
            return toAccountName
        }
        return nil
    }

    var expenseSummary: String {
        contexts.map { $0.description }.joined(separator: ", ")
    }

    var expenseCount: Int { contexts.count }
}
