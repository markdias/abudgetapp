//
//  HomeView.swift
//  abudgetapp
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var expandedCardID: Int? = nil
    @State private var isAnimating: Bool = false
    
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
                    VStack(spacing: 0) { // Removed negative spacing
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
                        .padding(.bottom, 0) // No padding between balance and accounts
                        
                        // Account summaries - moved up with no space between balance section
                        accountSummaries
                        
                        // Add significant spacing after account cards
                        Spacer()
                            .frame(height: 120) // Much more space to push quick actions down
                        
                        // Pots section before action buttons
                        potsSection
                        
                        // Quick action buttons - moved further down after pots
                        HStack(spacing: 20) {
                            quickActionButton(icon: "plus", title: "Add Income", action: addNewIncome)
                            quickActionButton(icon: "minus", title: "Add Expense", action: addNewExpense)
                            quickActionButton(icon: "chart.bar", title: "Reports", action: viewReports)
                        }
                        .padding(.vertical, 20) // More vertical padding
                        
                        // Recent transactions - now below quick action buttons
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
        VStack(alignment: .leading, spacing: 0) { 
            HStack {
                Text("Accounts")
                    .font(.headline)
                Spacer()
                Button(action: {
                    // Action to add a new account
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 0) // No padding between title and cards
            
            // Stacked card display with cards that can expand/collapse
            ZStack {
                if let expandedId = expandedCardID {
                    // Show only the expanded card
                    let expandedAccount = appState.accounts.first(where: { $0.id == expandedId })!
                    AccountCard(account: expandedAccount, isExpanded: true)
                        .zIndex(100)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                expandedCardID = nil
                                isAnimating = true
                                
                                // Reset animation flag after a delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isAnimating = false
                                }
                            }
                        }
                } else {
                    // Show all cards stacked when none is expanded
                    ForEach(Array(appState.accounts.enumerated()), id: \.element.id) { index, account in
                        AccountCard(account: account, isExpanded: false)
                            .offset(y: CGFloat(index * 60))
                            .zIndex(Double(index))
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    expandedCardID = account.id
                                    isAnimating = true
                                    
                                    // Reset animation flag after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isAnimating = false
                                    }
                                }
                            }
                            .disabled(isAnimating) // Prevent tapping during animation
                    }
                }
            }
            .padding(.top, 0) // No padding from title
            .frame(height: expandedCardID != nil ? 180 : (appState.accounts.isEmpty ? 130 : CGFloat(130 + ((appState.accounts.count - 1) * 60))))
            .padding(.bottom, 2) // Minimal padding at the bottom
        }
    }
    
    struct AccountCard: View {
        let account: Account
        let isExpanded: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header with name and bank logo
                HStack(alignment: .top) {
                    // Account name on left
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(account.type.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Balance on right
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("£\(String(format: "%.2f", abs(account.balance)))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Balance")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 8)
                
                // Only show additional details if the card is expanded
                if isExpanded {
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Details")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("Account Type:")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(account.type.capitalized)
                                .foregroundColor(.white)
                        }
                        
                        if let creditLimit = account.credit_limit, account.type == "credit" {
                            HStack {
                                Text("Credit Limit:")
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("£\(String(format: "%.2f", creditLimit))")
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text("Tap to collapse")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
                } else {
                    Spacer()
                    
                    // Card bottom info when not expanded
                    HStack {
                        // Card number
                        Text("•••• 4321")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        // Card icon
                        Image(systemName: iconForAccount(account.type))
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .frame(height: isExpanded ? 220 : 130)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        colorGradientStartForAccount(account.type),
                        colorGradientEndForAccount(account.type)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        
        // Icons for different account types
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
        
        // Colors for account card gradients
        private func colorGradientStartForAccount(_ type: String) -> Color {
            switch type {
            case "current":
                return Color.blue
            case "credit":
                return Color.red
            case "savings":
                return Color.green
            case "investment":
                return Color(red: 0.5, green: 0.4, blue: 0.9) // Purple
            default:
                return Color.gray
            }
        }
        
        private func colorGradientEndForAccount(_ type: String) -> Color {
            switch type {
            case "current":
                return Color.blue.opacity(0.6)
            case "credit":
                return Color.orange
            case "savings":
                return Color.green.opacity(0.6)
            case "investment":
                return Color.purple.opacity(0.6)
            default:
                return Color.gray.opacity(0.6)
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
