//  BudgetDataModels.swift
//  abudgetapp
//

import Foundation
import SwiftUI

// MARK: - Response Types
public struct MessageResponse: Codable {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

public struct ResetResponse: Codable {
    public let accounts: [Account]
    public let income_schedules: [IncomeSchedule]

    public init(accounts: [Account], income_schedules: [IncomeSchedule]) {
        self.accounts = accounts
        self.income_schedules = income_schedules
    }
}

public struct IncomeExecutionResponse: Codable {
    public let accounts: [Account]
    public let executed_count: Int

    public init(accounts: [Account], executed_count: Int) {
        self.accounts = accounts
        self.executed_count = executed_count
    }
}

// MARK: - Account Models
public struct Account: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public var balance: Double
    public let type: String
    public let accountType: String?
    public var credit_limit: Double?
    public var excludeFromReset: Bool?
    public var pots: [Pot]?
    public var scheduled_payments: [ScheduledPayment]?
    public var incomes: [Income]?
    public var expenses: [Expense]?
    
    public var formattedBalance: String {
        return "£\(String(format: "%.2f", abs(balance)))"
    }
    
    public var isCredit: Bool {
        return type == "credit"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }
    
    public init(id: Int, name: String, balance: Double, type: String, accountType: String? = nil,
         credit_limit: Double? = nil, excludeFromReset: Bool? = nil, pots: [Pot]? = nil,
         scheduled_payments: [ScheduledPayment]? = nil, incomes: [Income]? = nil, expenses: [Expense]? = nil) {
        self.id = id
        self.name = name
        self.balance = balance
        self.type = type
        self.accountType = accountType
        self.credit_limit = credit_limit
        self.excludeFromReset = excludeFromReset
        self.pots = pots
        self.scheduled_payments = scheduled_payments
        self.incomes = incomes
        self.expenses = expenses
    }
}

// MARK: - Pot Models
public struct Pot: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public var balance: Double
    public var excludeFromReset: Bool?
    public var scheduled_payments: [ScheduledPayment]?
    
    public init(id: Int, name: String, balance: Double, excludeFromReset: Bool? = nil,
         scheduled_payments: [ScheduledPayment]? = nil) {
        self.id = id
        self.name = name
        self.balance = balance
        self.excludeFromReset = excludeFromReset
        self.scheduled_payments = scheduled_payments
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Pot, rhs: Pot) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Transaction Models
public struct Income: Identifiable, Codable, Hashable {
    public let id: Int
    public let amount: Double
    public let description: String
    public let company: String
    public let date: String
    public let potName: String?

    public init(id: Int, amount: Double, description: String, company: String, date: String, potName: String? = nil) {
        self.id = id
        self.amount = amount
        self.description = description
        self.company = company
        self.date = date
        self.potName = potName
    }
    
    public static func == (lhs: Income, rhs: Income) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct Expense: Identifiable, Codable, Hashable {
    public let id: Int
    public let amount: Double
    public let description: String
    public let date: String
    public let toAccountId: Int?
    public let toPotName: String?

    public init(id: Int, amount: Double, description: String, date: String, toAccountId: Int? = nil, toPotName: String? = nil) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
        self.toAccountId = toAccountId
        self.toPotName = toPotName
    }
    
    public static func == (lhs: Expense, rhs: Expense) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct TransactionRecord: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let vendor: String
    public let amount: Double
    public let date: String
    public let fromAccountId: Int?
    public let toAccountId: Int
    public let toPotName: String?

    public init(id: Int, name: String, vendor: String, amount: Double, date: String, fromAccountId: Int? = nil, toAccountId: Int, toPotName: String? = nil) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.amount = amount
        self.date = date
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.toPotName = toPotName
    }

    public static func == (lhs: TransactionRecord, rhs: TransactionRecord) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Target Models
public struct TargetRecord: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let amount: Double
    public let date: String
    public let accountId: Int

    public init(id: Int, name: String, amount: Double, date: String, accountId: Int) {
        self.id = id
        self.name = name
        self.amount = amount
        self.date = date
        self.accountId = accountId
    }

    public static func == (lhs: TargetRecord, rhs: TargetRecord) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Scheduled Payment Models
public struct ScheduledPayment: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let amount: Double
    public let date: String
    public let company: String
    public let type: String?
    public var isCompleted: Bool?
    public var lastExecuted: String?
    
    // Add a unique generated ID for cases where the server doesn't provide one
    private let generatedId = UUID()
    
    // Make ID optional in the decoder but still conform to Identifiable
    public var identifier: Int { id }
    
    // Custom CodingKeys to handle the optional ID case
    private enum CodingKeys: String, CodingKey {
        case id, name, amount, date, company, type, isCompleted, lastExecuted
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, but use a random value if missing
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? Int.random(in: 100000..<999999)
        
        // Decode required fields
        self.name = try container.decode(String.self, forKey: .name)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.date = try container.decode(String.self, forKey: .date)
        self.company = try container.decode(String.self, forKey: .company)
        
        // Decode optional fields
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
        self.lastExecuted = try container.decodeIfPresent(String.self, forKey: .lastExecuted)
    }
    
    public init(id: Int, name: String, amount: Double, date: String, company: String, type: String? = nil,
         isCompleted: Bool? = nil, lastExecuted: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.date = date
        self.company = company
        self.type = type
        self.isCompleted = isCompleted
        self.lastExecuted = lastExecuted
    }
    
    public static func == (lhs: ScheduledPayment, rhs: ScheduledPayment) -> Bool {
        // If IDs are the same and not randomly generated, use them for comparison
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Schedule Models
public struct IncomeSchedule: Identifiable, Codable, Hashable {
    public let id: Int
    public let accountId: Int
    public let incomeId: Int
    public let amount: Double
    public let description: String
    public let company: String
    public let isActive: Bool
    public var isCompleted: Bool
    public var lastExecuted: String?
    
    public init(id: Int, accountId: Int, incomeId: Int, amount: Double, description: String, company: String,
         isActive: Bool, isCompleted: Bool, lastExecuted: String? = nil) {
        self.id = id
        self.accountId = accountId
        self.incomeId = incomeId
        self.amount = amount
        self.description = description
        self.company = company
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.lastExecuted = lastExecuted
    }
    
    public static func == (lhs: IncomeSchedule, rhs: IncomeSchedule) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Transfer Schedule Models
public struct TransferSchedule: Identifiable, Codable, Hashable {
    public let id: Int
    public let fromAccountId: Int
    public let fromPotName: String?
    public let toAccountId: Int
    public let toPotName: String?
    public let amount: Double
    public let description: String
    public let isActive: Bool
    public var isCompleted: Bool
    public var lastExecuted: String?

    public init(id: Int, fromAccountId: Int, fromPotName: String? = nil, toAccountId: Int, toPotName: String? = nil, amount: Double, description: String,
                isActive: Bool, isCompleted: Bool, lastExecuted: String? = nil) {
        self.id = id
        self.fromAccountId = fromAccountId
        self.fromPotName = fromPotName
        self.toAccountId = toAccountId
        self.toPotName = toPotName
        self.amount = amount
        self.description = description
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.lastExecuted = lastExecuted
    }

    public static func == (lhs: TransferSchedule, rhs: TransferSchedule) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Submission Types
public struct AccountSubmission: Codable {
    public let name: String
    public let balance: Double
    public let type: String
    public let accountType: String
    public var credit_limit: Double?
    public var excludeFromReset: Bool?
    
    public init(name: String, balance: Double, type: String, accountType: String, credit_limit: Double? = nil,
         excludeFromReset: Bool? = nil) {
        self.name = name
        self.balance = balance
        self.type = type
        self.accountType = accountType
        self.credit_limit = credit_limit
        self.excludeFromReset = excludeFromReset
    }
}

public struct PotSubmission: Codable {
    public let name: String
    public var balance: Double
    public var excludeFromReset: Bool?
    
    public init(name: String, balance: Double, excludeFromReset: Bool? = nil) {
        self.name = name
        self.balance = balance
        self.excludeFromReset = excludeFromReset
    }
}

public struct ExpenseSubmission: Codable {
    public let amount: Double
    public let description: String
    public var date: String?
    public var groupId: String?
    public var groupStatus: String?
    public var isScheduled: Bool?
    public var toAccountId: Int?
    public var toPotName: String?

    public init(amount: Double, description: String, date: String? = nil, groupId: String? = nil,
         groupStatus: String? = nil, isScheduled: Bool? = nil, toAccountId: Int? = nil, toPotName: String? = nil) {
        self.amount = amount
        self.description = description
        self.date = date
        self.groupId = groupId
        self.groupStatus = groupStatus
        self.isScheduled = isScheduled
        self.toAccountId = toAccountId
        self.toPotName = toPotName
    }
}

public struct IncomeSubmission: Codable {
    public let amount: Double
    public let description: String
    public let company: String
    public var date: String?
    public var potName: String?

    public init(amount: Double, description: String, company: String, date: String? = nil, potName: String? = nil) {
        self.amount = amount
        self.description = description
        self.company = company
        self.date = date
        self.potName = potName
    }
}

public struct TransactionSubmission: Codable {
    public let name: String
    public let vendor: String
    public let amount: Double
    public let date: String?
    public let fromAccountId: Int?
    public let toAccountId: Int
    public var toPotName: String?

    public init(name: String, vendor: String, amount: Double, date: String? = nil, fromAccountId: Int? = nil, toAccountId: Int, toPotName: String? = nil) {
        self.name = name
        self.vendor = vendor
        self.amount = amount
        self.date = date
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.toPotName = toPotName
    }
}

public struct TargetSubmission: Codable {
    public let name: String
    public let amount: Double
    public let date: String?
    public let accountId: Int

    public init(name: String, amount: Double, date: String? = nil, accountId: Int) {
        self.name = name
        self.amount = amount
        self.date = date
        self.accountId = accountId
    }
}

public struct ScheduledPaymentSubmission: Codable {
    public let name: String
    public let amount: Double
    public let date: String
    public let company: String
    public var type: String?
    public var isCompleted: Bool?
    public var lastExecuted: String?
    
    public init(name: String, amount: Double, date: String, company: String, type: String? = nil,
         isCompleted: Bool? = nil, lastExecuted: String? = nil) {
        self.name = name
        self.amount = amount
        self.date = date
        self.company = company
        self.type = type
        self.isCompleted = isCompleted
        self.lastExecuted = lastExecuted
    }
}

public struct IncomeScheduleSubmission: Codable {
    public let accountId: Int
    public let incomeId: Int
    public let amount: Double
    public let description: String
    public let company: String
    
    public init(accountId: Int, incomeId: Int, amount: Double, description: String, company: String) {
        self.accountId = accountId
        self.incomeId = incomeId
        self.amount = amount
        self.description = description
        self.company = company
    }
}

public struct TransferScheduleSubmission: Codable {
    public let fromAccountId: Int
    public var fromPotName: String?
    public let toAccountId: Int
    public var toPotName: String?
    public let amount: Double
    public let description: String

    public init(fromAccountId: Int, fromPotName: String? = nil, toAccountId: Int, toPotName: String? = nil, amount: Double, description: String) {
        self.fromAccountId = fromAccountId
        self.fromPotName = fromPotName
        self.toAccountId = toAccountId
        self.toPotName = toPotName
        self.amount = amount
        self.description = description
    }
}
