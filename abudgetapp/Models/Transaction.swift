//
//  Transaction.swift
//  abudgetapp
//

import Foundation
import SwiftUI

public struct Transaction: Identifiable {
    public let id: UUID
    public let title: String
    public let amount: Double
    public let date: Date
    public let category: Category
    public let isIncome: Bool
    public let isPayment: Bool
    
    public init(id: UUID = UUID(), title: String, amount: Double, date: Date, category: Category, isIncome: Bool, isPayment: Bool = false) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.isIncome = isIncome
        self.isPayment = isPayment
    }
    
    public var formattedAmount: String {
        let sign = isIncome ? "+" : "-"
        return "\(sign)£\(String(format: "%.2f", abs(amount)))"
    }
    
    public var amountColor: Color {
        return isIncome ? .green : .red
    }
}

// Sample data for preview
extension Transaction {
    static let sampleData = [
        Transaction(title: "Grocery Shopping", amount: 42.50, date: Date().addingTimeInterval(-86400), category: .food, isIncome: false),
        Transaction(title: "Monthly Salary", amount: 2500.00, date: Date().addingTimeInterval(-172800), category: .salary, isIncome: true),
        Transaction(title: "Netflix Subscription", amount: 9.99, date: Date().addingTimeInterval(-259200), category: .entertainment, isIncome: false),
        Transaction(title: "Bus Ticket", amount: 2.40, date: Date(), category: .transport, isIncome: false)
    ]
}
