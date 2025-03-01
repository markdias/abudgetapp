//
//  Budget.swift
//  abudgetapp
//

import Foundation
import SwiftUI

public struct BudgetItem: Identifiable {
    public let id = UUID()
    public let category: Category
    public let allocated: Double
    public let spent: Double
    
    public init(category: Category, allocated: Double, spent: Double) {
        self.category = category
        self.allocated = allocated
        self.spent = spent
    }
    
    public var remaining: Double {
        allocated - spent
    }
    
    public var percentUsed: Double {
        allocated > 0 ? min(spent / allocated, 1) : 0
    }
}

public enum Category: String, CaseIterable, Identifiable {
    case utilities = "Utilities"
    case food = "Food"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case health = "Health"
    case shopping = "Shopping"
    case other = "Other"
    case salary = "Salary"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .utilities: return "bolt"
        case .food: return "fork.knife"
        case .transport: return "bus"
        case .entertainment: return "tv"
        case .health: return "heart"
        case .shopping: return "cart"
        case .other: return "questionmark.circle"
        case .salary: return "banknote"
        }
    }
}

// Sample data for preview
extension BudgetItem {
    static let sampleData = [
        BudgetItem(category: .food, allocated: 300, spent: 120),
        BudgetItem(category: .transport, allocated: 150, spent: 65),
        BudgetItem(category: .entertainment, allocated: 100, spent: 95),
        BudgetItem(category: .shopping, allocated: 200, spent: 150),
        BudgetItem(category: .utilities, allocated: 250, spent: 230),
        BudgetItem(category: .health, allocated: 100, spent: 20),
        BudgetItem(category: .other, allocated: 50, spent: 35)
    ]
}
