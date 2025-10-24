import Foundation

enum BudgetDataError: LocalizedError {
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
            return "Failed to save data: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

extension LocalBudgetStore.StoreError {
    var asBudgetDataError: BudgetDataError {
        switch self {
        case .notFound(let message):
            return .notFound(message)
        case .invalidOperation(let message):
            return .invalidOperation(message)
        case .persistence(let error):
            return .persistence(error.localizedDescription)
        }
    }
}
