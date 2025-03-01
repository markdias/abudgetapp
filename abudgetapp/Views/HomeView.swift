//
//  HomeView.swift
//  abudgetapp
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
    // Computed properties for summary data
    var totalBalance: Double {
        appState.accounts.reduce(0) { $0 + $1.balance }
    }
    
    var todaySpending: Double {
        let today = Calendar.current.startOfDay(for: Date())
        
        return appState.transactions
            .filter { !$0.isIncome && Calendar.current.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.amount }
    }
    
    var recentTransactions: [Transaction] {
        // Get the 5 most recent transactions
        Array(appState.transactions.sorted(by: { $0.date > $1.date }).prefix(5))
    }
    
    var body: some View {
        NavigationView {
            if appState.isLoading {
                ProgressView("Loading data...")
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Balance card
                        VStack(spacing: 4) {
                            Text("Current Balance")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("£\(String(format: "%.2f", totalBalance))")
                                .font(.system(size: 34, weight: .bold))
                            
                            Text("Spent today: £\(String(format: "%.2f", todaySpending))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
                        
                        // Account summaries
                        accountSummaries
                        
                        // Pots section
                        potsSection
                        
                        // Quick action buttons
                        HStack(spacing: 20) {
                            quickActionButton(icon: "plus", title: "Add Income", action: addNewIncome)
                            quickActionButton(icon: "minus", title: "Add Expense", action: addNewExpense)
                            quickActionButton(icon: "chart.bar", title: "Reports", action: viewReports)
                        }
                        
                        // Recent transactions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Transactions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if recentTransactions.isEmpty {
                                Text("No recent transactions")
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(recentTransactions) { transaction in
                                    TransactionRow(transaction: transaction)
                                }
                                
                                Button("See all transactions") {
                                    // Navigate to transactions tab
                                    selectTransactionsTab()
                                }
                                .font(.subheadline)
                                .foregroundColor(.purple)
                                .padding(.horizontal)
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Home")
                .refreshable {
                    appState.fetchData()
                }
            }
        }
        .alert(isPresented: $appState.showingError) {
            Alert(
                title: Text("Error"),
                message: Text(appState.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var accountSummaries: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(appState.accounts) { account in
                AccountSummaryRow(account: account)
            }
        }
    }
    
    var potsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pots")
                .font(.headline)
                .padding(.horizontal)
            
            // Get all pots from all accounts
            let accountsWithPots = appState.accounts.filter { $0.pots != nil && !$0.pots!.isEmpty }
            
            if accountsWithPots.isEmpty {
                Text("No pots found")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(accountsWithPots) { account in
                    if let pots = account.pots {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(account.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal)
                            
                            ForEach(pots) { pot in
                                potRow(pot: pot, accountName: account.name)
                            }
                        }
                        .padding(.bottom, 10)
                    }
                }
            }
        }
    }
    
    func potRow(pot: Pot, accountName: String) -> some View {
        HStack {
            // Icon
            Image(systemName: "envelope.fill")
                .foregroundColor(.white)
                .padding(10)
                .background(Color.purple)
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(pot.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(accountName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("£\(String(format: "%.2f", pot.balance))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(pot.balance >= 0 ? .green : .red)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func quickActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.purple)
                    .cornerRadius(25)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Action Methods
    private func addNewIncome() {
        // Will implement later
    }
    
    private func addNewExpense() {
        // Will implement later
    }
    
    private func viewReports() {
        // Will implement later
    }
    
    private func selectTransactionsTab() {
        // Change the selected tab to Transactions (index 1)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let tabBarController = windowScene.windows.first?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 1
        }
    }
}

struct AccountSummaryRow: View {
    let account: Account
    
    var body: some View {
        HStack {
            // Icon based on account type
            Image(systemName: iconForAccount(account.type))
                .foregroundColor(.white)
                .padding(10)
                .background(colorForAccount(account.type))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(account.type.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(account.formattedBalance)
                .font(.subheadline)
                .foregroundColor(account.balance >= 0 ? (account.type == "credit" ? .orange : .green) : .red)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func iconForAccount(_ type: String) -> String {
        switch type {
        case "current":
            return "creditcard"
        case "credit":
            return "creditcard.fill"
        case "savings":
            return "banknote"
        case "investment":
            return "chart.line.uptrend.xyaxis"
        default:
            return "dollarsign.circle"
        }
    }
    
    private func colorForAccount(_ type: String) -> Color {
        switch type {
        case "current":
            return .blue
        case "credit":
            return .orange
        case "savings":
            return .green
        case "investment":
            return .purple
        default:
            return .gray
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            Image(systemName: transaction.category.icon)
                .foregroundColor(.white)
                .padding(10)
                .background(Color.purple)
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(transaction.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transaction.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(transaction.formattedAmount)
                .font(.subheadline)
                .foregroundColor(transaction.isIncome ? .green : .red)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
