//
//  BudgetView.swift
//  abudgetapp
//

import SwiftUI
import Combine
import Foundation
#if os(macOS)
import AppKit
#endif

struct BudgetView: View {
    @EnvironmentObject var appState: AppState
    
    // Computed properties for budget summary
    var totalAllocated: Double {
        appState.budgetItems.reduce(0) { $0 + $1.allocated }
    }
    
    var totalSpent: Double {
        appState.budgetItems.reduce(0) { $0 + $1.spent }
    }
    
    var remaining: Double {
        totalAllocated - totalSpent
    }
    
    var percentUsed: Double {
        totalAllocated > 0 ? min(totalSpent / totalAllocated, 1) : 0
    }
    
    var body: some View {
        NavigationView {
            if appState.isLoading {
                ProgressView("Loading budget data...")
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Monthly budget summary card
                        VStack(spacing: 4) {
                            Text("Monthly Budget")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("£\(String(format: "%.2f", totalAllocated))")
                                .font(.system(size: 28, weight: .bold))
                            
                            HStack {
                                Text("£\(String(format: "%.2f", totalSpent)) spent")
                                    .foregroundColor(.secondary)
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("£\(String(format: "%.2f", remaining)) remaining")
                                    .foregroundColor(remaining >= 0 ? .green : .red)
                            }
                            .font(.subheadline)
                            .padding(.top, 4)
                            
                            // Overall progress
                            ProgressView(value: percentUsed)
                                .tint(.purple)
                                .padding(.top, 8)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.background)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
                        
                        // Budget categories
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Categories")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if appState.budgetItems.isEmpty {
                                Text("No budget categories found")
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(appState.budgetItems) { item in
                                    BudgetItemRow(budgetItem: item)
                                }
                            }
                        }
                        
                        // Scheduled payments section
                        scheduledPaymentsSection
                    }
                    .padding()
                }
                .navigationTitle("Budget")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            // Action to edit budget
                        }) {
                            Text("Edit")
                        }
                    }
                }
                .refreshable {
                    appState.fetchData()
                }
            }
        }
        .background(Color.background)
        .alert(isPresented: $appState.showingError) {
            Alert(
                title: Text("Error"),
                message: Text(appState.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var scheduledPaymentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Payments")
                .font(.headline)
                .padding(.horizontal)
            
            // Get all scheduled payments from all accounts and pots
            let scheduledPayments = getScheduledPayments()
            
            if scheduledPayments.isEmpty {
                Text("No upcoming payments")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(scheduledPayments.prefix(5)) { payment in
                    scheduledPaymentRow(payment: payment)
                }
                
                if scheduledPayments.count > 5 {
                    Button("See all scheduled payments") {
                        // Navigate to full list
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
        }
    }
    
    func scheduledPaymentRow(payment: ScheduledPaymentWithSource) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(payment.payment.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(payment.accountName)\(payment.potName != nil ? " / \(payment.potName!)" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(payment.formattedAmount)
                    .foregroundColor(.red)
                
                Text("Due: \(formatDueDate(payment.payment.date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.background)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // Helper function to get all scheduled payments
    func getScheduledPayments() -> [ScheduledPaymentWithSource] {
        var allPayments = [ScheduledPaymentWithSource]()
        
        for account in appState.accounts {
            // Add payments directly on the account
            if let payments = account.scheduled_payments {
                for payment in payments {
                    allPayments.append(
                        ScheduledPaymentWithSource(
                            payment: payment,
                            accountName: account.name,
                            potName: nil
                        )
                    )
                }
            }
            
            // Add payments in pots
            if let pots = account.pots {
                for pot in pots {
                    if let payments = pot.scheduled_payments {
                        for payment in payments {
                            allPayments.append(
                                ScheduledPaymentWithSource(
                                    payment: payment,
                                    accountName: account.name,
                                    potName: pot.name
                                )
                            )
                        }
                    }
                }
            }
        }
        
        // Sort by date (using a safer approach)
        return allPayments.sorted { payment1, payment2 in
            // Convert dates to Day if possible
            let day1 = Int(payment1.payment.date) ?? 0
            let day2 = Int(payment2.payment.date) ?? 0
            return day1 < day2
        }
    }
    
    // Helper to format the due date
    func formatDueDate(_ dateString: String) -> String {
        if let day = Int(dateString) {
            // If it's just a day number, show as "Day X of month"
            return "\(day.ordinal) of month"
        } else if let date = ISO8601DateFormatter().date(from: dateString) {
            // If it's a full date string, format nicely
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        } else {
            return dateString
        }
    }
}

// Helper struct to track payment source
struct ScheduledPaymentWithSource: Identifiable {
    let payment: ScheduledPayment
    let accountName: String
    let potName: String?

    var id: Int { payment.id }

    var formattedAmount: String {
        String(format: "$%.2f", payment.amount)
    }
}

struct BudgetItemRow: View {
    let budgetItem: BudgetItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: budgetItem.category.icon)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.purple)
                    .cornerRadius(8)
                
                Text(budgetItem.category.rawValue)
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("£\(String(format: "%.2f", budgetItem.spent)) of £\(String(format: "%.2f", budgetItem.allocated))")
                        .font(.subheadline)
                    
                    Text("£\(String(format: "%.2f", budgetItem.remaining)) left")
                        .font(.caption)
                        .foregroundColor(budgetItem.remaining > 0 ? .green : .red)
                }
            }
            
            // Progress bar
            ProgressView(value: budgetItem.percentUsed)
                .tint(
                    budgetItem.percentUsed < 0.7 ? .green :
                    budgetItem.percentUsed < 0.9 ? .yellow : .red
                )
        }
        .padding()
        .background(Color.background)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Helper extension to provide a background color that works on both macOS and iOS
extension Color {
    static var background: Color {
        #if os(macOS)
        return Color(nsColor: NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
}

// Extension for ordinal numbers
extension Int {
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    BudgetView()
        .environmentObject(AppState())
}
