// filepath: /Users/markdias/project/abudgetapp/abudgetapp/Models/APIModels.swift
//
//  APIModels.swift
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

public struct ExclusionResponse: Codable {
    public let excludeFromReset: Bool
    
    public init(excludeFromReset: Bool) {
        self.excludeFromReset = excludeFromReset
    }
}

public struct ResetResponse: Codable {
    public let accounts: [Account]
    public let income_schedules: [IncomeSchedule]
    public let transfer_schedules: [TransferSchedule]
    
    public init(accounts: [Account], income_schedules: [IncomeSchedule], transfer_schedules: [TransferSchedule]) {
        self.accounts = accounts
        self.income_schedules = income_schedules
        self.transfer_schedules = transfer_schedules
    }
}

public struct TransferExecutionResponse: Codable {
    public let success: Bool?
    public let accounts: [Account]?
    public let error: String?
    
    public init(success: Bool? = nil, accounts: [Account]? = nil, error: String? = nil) {
        self.success = success
        self.accounts = accounts
        self.error = error
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

public struct CardOrderResponse: Codable {
    public let success: Bool
    public let message: String?
    public let accounts: [Account]?

    public init(success: Bool, message: String? = nil, accounts: [Account]? = nil) {
        self.success = success
        self.message = message
        self.accounts = accounts
    }
}

public struct AvailableTransfers: Codable {
    public let byAccount: [AvailableAccountTransfer]
    public let byPot: [AvailablePotTransfer]

    public init(byAccount: [AvailableAccountTransfer], byPot: [AvailablePotTransfer]) {
        self.byAccount = byAccount
        self.byPot = byPot
    }
}

public struct AvailableAccountTransfer: Codable, Identifiable {
    public let id = UUID()
    public let destinationId: Int
    public let destinationType: String
    public let destinationName: String
    public let accountName: String
    public let totalAmount: Double
    public let items: [AvailableTransferItem]

    enum CodingKeys: String, CodingKey {
        case destinationId
        case destinationType
        case destinationName
        case accountName
        case totalAmount
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.destinationId = try container.decode(Int.self, forKey: .destinationId)
        self.destinationType = try container.decode(String.self, forKey: .destinationType)
        self.destinationName = try container.decode(String.self, forKey: .destinationName)
        self.accountName = try container.decode(String.self, forKey: .accountName)
        self.totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        self.items = try container.decode([AvailableTransferItem].self, forKey: .items)
    }

    public init(destinationId: Int, destinationType: String, destinationName: String, accountName: String, totalAmount: Double, items: [AvailableTransferItem]) {
        self.destinationId = destinationId
        self.destinationType = destinationType
        self.destinationName = destinationName
        self.accountName = accountName
        self.totalAmount = totalAmount
        self.items = items
    }
}

public struct AvailablePotTransfer: Codable, Identifiable {
    public let id = UUID()
    public let destinationId: Int
    public let destinationType: String
    public let destinationName: String
    public let accountName: String
    public let totalAmount: Double
    public let items: AvailablePotTransferItems

    enum CodingKeys: String, CodingKey {
        case destinationId
        case destinationType
        case destinationName
        case accountName
        case totalAmount
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.destinationId = try container.decode(Int.self, forKey: .destinationId)
        self.destinationType = try container.decode(String.self, forKey: .destinationType)
        self.destinationName = try container.decode(String.self, forKey: .destinationName)
        self.accountName = try container.decode(String.self, forKey: .accountName)
        self.totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        self.items = try container.decode(AvailablePotTransferItems.self, forKey: .items)
    }

    public init(destinationId: Int, destinationType: String, destinationName: String, accountName: String, totalAmount: Double, items: AvailablePotTransferItems) {
        self.destinationId = destinationId
        self.destinationType = destinationType
        self.destinationName = destinationName
        self.accountName = accountName
        self.totalAmount = totalAmount
        self.items = items
    }
}

public struct AvailablePotTransferItems: Codable {
    public let directDebits: [AvailableTransferItem]
    public let cardPayments: [AvailableTransferItem]

    public init(directDebits: [AvailableTransferItem], cardPayments: [AvailableTransferItem]) {
        self.directDebits = directDebits
        self.cardPayments = cardPayments
    }
}

public struct AvailableTransferItem: Codable, Identifiable {
    public let id: Int
    public let amount: Double
    public let description: String
    public let date: String?
    public let company: String?
    public let type: String

    public init(id: Int, amount: Double, description: String, date: String? = nil, company: String? = nil, type: String) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
        self.company = company
        self.type = type
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
    
    public init(id: Int, amount: Double, description: String, company: String, date: String) {
        self.id = id
        self.amount = amount
        self.description = description
        self.company = company
        self.date = date
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
    
    public init(id: Int, amount: Double, description: String, date: String) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
    }
    
    public static func == (lhs: Expense, rhs: Expense) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
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
public enum TransferDestinationKind: String, Codable, CaseIterable {
    case account
    case pot

    public var displayLabel: String {
        switch self {
        case .account: return "Expense · Main Account"
        case .pot: return "Transfer · Pot"
        }
    }

    public var helperDescription: String {
        switch self {
        case .account: return "Funds remain in the main account balance."
        case .pot: return "Funds move into the selected pot."
        }
    }
}

public struct TransferSchedule: Identifiable, Codable, Hashable {
    public let id: Int
    public var fromAccountId: Int?
    public var fromPotId: String?
    public let toAccountId: Int
    public var toPotName: String?
    public let amount: Double
    public let description: String
    public let isActive: Bool
    public var isCompleted: Bool
    public var items: [TransferItem]?
    public var isDirectPotTransfer: Bool?
    public var lastExecuted: String?

    public init(id: Int, fromAccountId: Int? = nil, fromPotId: String? = nil, toAccountId: Int, toPotName: String? = nil,
         amount: Double, description: String, isActive: Bool, isCompleted: Bool, items: [TransferItem]? = nil,
         isDirectPotTransfer: Bool? = nil, lastExecuted: String? = nil) {
        self.id = id
        self.fromAccountId = fromAccountId
        self.fromPotId = fromPotId
        self.toAccountId = toAccountId
        self.toPotName = toPotName
        self.amount = amount
        self.description = description
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.items = items
        self.isDirectPotTransfer = isDirectPotTransfer
        self.lastExecuted = lastExecuted
    }

    public var destinationKind: TransferDestinationKind {
        if let name = toPotName, !name.isEmpty {
            return .pot
        }
        return .account
    }
    
    public static func == (lhs: TransferSchedule, rhs: TransferSchedule) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct TransferItem: Codable, Hashable {
    public let id: Int?
    public let amount: Double
    public let description: String
    public let date: String?
    public let company: String?
    public let type: String?
    
    public init(id: Int? = nil, amount: Double, description: String, date: String? = nil, company: String? = nil,
         type: String? = nil) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
        self.company = company
        self.type = type
    }
    
    public func hash(into hasher: inout Hasher) {
        if let id = id {
            hasher.combine(id)
        } else {
            hasher.combine(description)
            hasher.combine(amount)
        }
    }
}

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
    
    public init(amount: Double, description: String, date: String? = nil, groupId: String? = nil,
         groupStatus: String? = nil, isScheduled: Bool? = nil) {
        self.amount = amount
        self.description = description
        self.date = date
        self.groupId = groupId
        self.groupStatus = groupStatus
        self.isScheduled = isScheduled
    }
}

public struct IncomeSubmission: Codable {
    public let amount: Double
    public let description: String
    public let company: String
    public var date: String?
    
    public init(amount: Double, description: String, company: String, date: String? = nil) {
        self.amount = amount
        self.description = description
        self.company = company
        self.date = date
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

public struct TransferScheduleSubmission: Codable {
    public var fromAccountId: Int?
    public var fromPotId: String?
    public let toAccountId: Int
    public var toPotName: String?
    public let amount: Double
    public let description: String
    public var items: [TransferItem]?
    public var isDirectPotTransfer: Bool?
    
    public init(fromAccountId: Int? = nil, fromPotId: String? = nil, toAccountId: Int, toPotName: String? = nil,
         amount: Double, description: String, items: [TransferItem]? = nil, isDirectPotTransfer: Bool? = nil) {
        self.fromAccountId = fromAccountId
        self.fromPotId = fromPotId
        self.toAccountId = toAccountId
        self.toPotName = toPotName
        self.amount = amount
        self.description = description
        self.items = items
        self.isDirectPotTransfer = isDirectPotTransfer
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