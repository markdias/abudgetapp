import Foundation

// Assuming there's a duplicate Category enum, rename this one to TransactionCategory
enum TransactionCategory: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }
    
    case general = "General"
    case food = "Food & Drink"
    case shopping = "Shopping"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case utilities = "Utilities"
    case health = "Health & Fitness"
    case education = "Education"
    case travel = "Travel"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .general: return "list.bullet"
        case .food: return "fork.knife"
        case .shopping: return "cart"
        case .transport: return "car"
        case .entertainment: return "tv"
        case .utilities: return "bolt"
        case .health: return "heart"
        case .education: return "book"
        case .travel: return "airplane"
        case .other: return "ellipsis"
        }
    }
}

// Assuming there's a duplicate Transaction struct, no changes needed if it's unique
// If there's another Transaction struct elsewhere that's truly a duplicate, remove it.
// If it's different, rename it (e.g., CoreTransaction, NetworkTransaction, etc.)
struct BudgetTransaction: Identifiable, Codable {
    let id: UUID
    let date: Date
    let title: String
    let amount: Double
    let isIncome: Bool
    let category: TransactionCategory // Use the renamed enum
}

// Assuming there's a duplicate BudgetItem struct, rename this one to FinancialGoal
struct FinancialGoal: Identifiable, Codable {
    let id: UUID
    let name: String
    let targetAmount: Double
    let currentAmount: Double
    let category: TransactionCategory // Use the renamed enum
    let dueDate: Date
}
