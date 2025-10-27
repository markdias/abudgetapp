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
    public var monthlyBaselineBalance: Double?
    public var monthlyBaselineMonth: String?
    
    public var formattedBalance: String {
        let amount: Double = {
            if isCredit {
                return -abs(balance)
            }
            return balance
        }()
        let absolute = String(format: "%.2f", abs(amount))
        return amount < 0 ? "-£\(absolute)" : "£\(absolute)"
    }

    public var availableCredit: Double? {
        guard isCredit, let limit = credit_limit else { return nil }
        if balance >= 0 {
            return max(0, limit - balance)
        } else {
            return max(0, limit + balance)
        }
    }
    
    public var isCredit: Bool {
        return type == "credit"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(balance)
        hasher.combine(type)
        hasher.combine(accountType)
        hasher.combine(credit_limit)
        hasher.combine(excludeFromReset)
        hasher.combine(pots)
        hasher.combine(scheduled_payments)
        hasher.combine(incomes)
        hasher.combine(expenses)
        hasher.combine(monthlyBaselineBalance)
        hasher.combine(monthlyBaselineMonth)
    }
    
    public static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.balance == rhs.balance &&
            lhs.type == rhs.type &&
            lhs.accountType == rhs.accountType &&
            lhs.credit_limit == rhs.credit_limit &&
            lhs.excludeFromReset == rhs.excludeFromReset &&
            lhs.pots == rhs.pots &&
            lhs.scheduled_payments == rhs.scheduled_payments &&
            lhs.incomes == rhs.incomes &&
            lhs.expenses == rhs.expenses &&
            lhs.monthlyBaselineBalance == rhs.monthlyBaselineBalance &&
            lhs.monthlyBaselineMonth == rhs.monthlyBaselineMonth
    }
    
    public init(id: Int, name: String, balance: Double, type: String, accountType: String? = nil,
         credit_limit: Double? = nil, excludeFromReset: Bool? = nil, pots: [Pot]? = nil,
         scheduled_payments: [ScheduledPayment]? = nil, incomes: [Income]? = nil, expenses: [Expense]? = nil,
         monthlyBaselineBalance: Double? = nil, monthlyBaselineMonth: String? = nil) {
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
        self.monthlyBaselineBalance = monthlyBaselineBalance
        self.monthlyBaselineMonth = monthlyBaselineMonth
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
        hasher.combine(name)
        hasher.combine(balance)
        hasher.combine(excludeFromReset)
        hasher.combine(scheduled_payments)
    }
    
    public static func == (lhs: Pot, rhs: Pot) -> Bool {
        return lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.balance == rhs.balance &&
            lhs.excludeFromReset == rhs.excludeFromReset &&
            lhs.scheduled_payments == rhs.scheduled_payments
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
    public enum Kind: String, Codable, Hashable {
        case scheduled
        case creditCardCharge = "credit_card_charge"
    }

    public let id: Int
    public let name: String
    public let vendor: String
    public let amount: Double
    public let date: String
    public let fromAccountId: Int?
    public let toAccountId: Int
    public let toPotName: String?
    public let paymentType: String? // "direct_debit" or "card"
    public let linkedCreditAccountId: Int?
    public let kind: Kind

    public init(
        id: Int,
        name: String,
        vendor: String,
        amount: Double,
        date: String,
        fromAccountId: Int? = nil,
        toAccountId: Int,
        toPotName: String? = nil,
        paymentType: String? = nil,
        linkedCreditAccountId: Int? = nil,
        kind: Kind = .scheduled
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.amount = amount
        self.date = date
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.toPotName = toPotName
        self.paymentType = paymentType
        self.linkedCreditAccountId = linkedCreditAccountId
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case vendor
        case amount
        case date
        case fromAccountId
        case toAccountId
        case toPotName
        case paymentType
        case linkedCreditAccountId
        case kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        vendor = try container.decode(String.self, forKey: .vendor)
        amount = try container.decode(Double.self, forKey: .amount)
        date = try container.decode(String.self, forKey: .date)
        fromAccountId = try container.decodeIfPresent(Int.self, forKey: .fromAccountId)
        toAccountId = try container.decode(Int.self, forKey: .toAccountId)
        toPotName = try container.decodeIfPresent(String.self, forKey: .toPotName)
        paymentType = try container.decodeIfPresent(String.self, forKey: .paymentType)
        linkedCreditAccountId = try container.decodeIfPresent(Int.self, forKey: .linkedCreditAccountId)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .scheduled
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(vendor, forKey: .vendor)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(fromAccountId, forKey: .fromAccountId)
        try container.encode(toAccountId, forKey: .toAccountId)
        try container.encodeIfPresent(toPotName, forKey: .toPotName)
        try container.encodeIfPresent(paymentType, forKey: .paymentType)
        try container.encodeIfPresent(linkedCreditAccountId, forKey: .linkedCreditAccountId)
        try container.encode(kind, forKey: .kind)
    }

    public static func == (lhs: TransactionRecord, rhs: TransactionRecord) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct ProcessedTransactionLog: Identifiable, Codable, Hashable {
    public let id: Int
    public let paymentId: Int
    public let accountId: Int
    public let potName: String?
    public let amount: Double
    public let day: Int
    public let name: String
    public let company: String
    public let paymentType: String?
    public let processedAt: String
    public let period: String
    public let wasManual: Bool

    public init(
        id: Int,
        paymentId: Int,
        accountId: Int,
        potName: String?,
        amount: Double,
        day: Int,
        name: String,
        company: String,
        paymentType: String?,
        processedAt: String,
        period: String,
        wasManual: Bool
    ) {
        self.id = id
        self.paymentId = paymentId
        self.accountId = accountId
        self.potName = potName
        self.amount = amount
        self.day = day
        self.name = name
        self.company = company
        self.paymentType = paymentType
        self.processedAt = processedAt
        self.period = period
        self.wasManual = wasManual
    }

    public static func == (lhs: ProcessedTransactionLog, rhs: ProcessedTransactionLog) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct ProcessedTransactionSkip: Identifiable, Codable, Hashable {
    public let id: String
    public let paymentId: Int
    public let accountId: Int
    public let potName: String?
    public let reason: String

    public init(paymentId: Int, accountId: Int, potName: String?, reason: String) {
        self.id = UUID().uuidString
        self.paymentId = paymentId
        self.accountId = accountId
        self.potName = potName
        self.reason = reason
    }

    public static func == (lhs: ProcessedTransactionSkip, rhs: ProcessedTransactionSkip) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct ProcessTransactionsResult: Codable {
    public let processed: [ProcessedTransactionLog]
    public let skipped: [ProcessedTransactionSkip]
    public let accounts: [Account]
    public let transactions: [TransactionRecord]
    public let effectiveDay: Int
    public let transferExecutedAt: String?
    public let blockedReason: String?

    public init(
        processed: [ProcessedTransactionLog],
        skipped: [ProcessedTransactionSkip],
        accounts: [Account],
        transactions: [TransactionRecord],
        effectiveDay: Int,
        transferExecutedAt: String?,
        blockedReason: String? = nil
    ) {
        self.processed = processed
        self.skipped = skipped
        self.accounts = accounts
        self.transactions = transactions
        self.effectiveDay = effectiveDay
        self.transferExecutedAt = transferExecutedAt
        self.blockedReason = blockedReason
    }
}

public struct BalanceReductionLog: Identifiable, Codable, Hashable {
    public let id: Int
    public let timestamp: String
    public let monthKey: String
    public let dayOfMonth: Int
    public let accountId: Int
    public let accountName: String
    public let baselineBalance: Double
    public let resultingBalance: Double
    public let reductionAmount: Double

    public init(
        id: Int,
        timestamp: String,
        monthKey: String,
        dayOfMonth: Int,
        accountId: Int,
        accountName: String,
        baselineBalance: Double,
        resultingBalance: Double,
        reductionAmount: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.monthKey = monthKey
        self.dayOfMonth = dayOfMonth
        self.accountId = accountId
        self.accountName = accountName
        self.baselineBalance = baselineBalance
        self.resultingBalance = resultingBalance
        self.reductionAmount = reductionAmount
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
    public var paymentType: String?
    public var linkedCreditAccountId: Int?

    public init(
        name: String,
        vendor: String,
        amount: Double,
        date: String? = nil,
        fromAccountId: Int? = nil,
        toAccountId: Int,
        toPotName: String? = nil,
        paymentType: String? = nil,
        linkedCreditAccountId: Int? = nil
    ) {
        self.name = name
        self.vendor = vendor
        self.amount = amount
        self.date = date
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.toPotName = toPotName
        self.paymentType = paymentType
        self.linkedCreditAccountId = linkedCreditAccountId
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
