import SwiftUI
import Combine

@main
struct AbudgetApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .accentColor(.purple)
                .onAppear {
                    APIService.shared.updateBaseURL("http://localhost:3000")
                    appState.fetchData()
                }
        }
    }
}

// App state to manage and share data across views
class AppState: ObservableObject {
    // Published properties for UI updates
    @Published var transactions: [Transaction] = []
    @Published var budgetItems: [BudgetItem] = []
    
    // API data
    @Published var accounts: [Account] = []
    @Published var savingsAndInvestments: [Account] = []
    @Published var transferSchedules: [TransferSchedule] = []
    @Published var incomeSchedules: [IncomeSchedule] = []
    
    // Loading and error states
    @Published var isLoading: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String? = nil
    @Published var error: String? = nil {
        didSet {
            if error != nil {
                errorMessage = error
                showingError = true
                print("Error set: \(error!)")
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Data Fetching Methods
    func fetchData() {
        isLoading = true
        error = nil
        print("Fetching data from API...")
        fetchAccounts()
        fetchSavingsAndInvestments()
        fetchTransferSchedules()
        fetchIncomeSchedules()
    }
    
    func fetchAccounts() {
        print("Requesting accounts from API...")
        
        APIService.shared.getAccounts()
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = "Failed to fetch accounts: \(err.localizedDescription)"
                    print("Error fetching accounts: \(err)")
                }
            }, receiveValue: { [weak self] (accounts: [Account]) in
                print("Received \(accounts.count) accounts from API")
                self?.accounts = accounts
                self?.updateTransactionsFromAccounts()
                self?.updateBudgetItemsFromAccounts()
            })
            .store(in: &cancellables)
    }
    
    func fetchSavingsAndInvestments() {
        APIService.shared.getSavingsInvestments()
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                if case .failure(let err) = completion {
                    print("Error fetching savings/investments: \(err)")
                }
            }, receiveValue: { [weak self] (accounts: [Account]) in
                self?.savingsAndInvestments = accounts
            })
            .store(in: &cancellables)
    }
    
    func fetchTransferSchedules() {
        APIService.shared.getTransferSchedules()
            .sink(receiveCompletion: { (completion: Subscribers.Completion<Error>) in
                if case .failure(let err) = completion {
                    print("Error fetching transfer schedules: \(err)")
                }
            }, receiveValue: { [weak self] (schedules: [TransferSchedule]) in
                self?.transferSchedules = schedules
            })
            .store(in: &cancellables)
    }
    
    func fetchIncomeSchedules() {
        APIService.shared.getIncomeSchedules()
            .sink(receiveCompletion: { (completion: Subscribers.Completion<Error>) in
                if case .failure(let err) = completion {
                    print("Error fetching income schedules: \(err)")
                }
            }, receiveValue: { [weak self] (schedules: [IncomeSchedule]) in
                self?.incomeSchedules = schedules
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Account Methods
    func addAccount(_ account: AccountSubmission, completion: @escaping (Bool) -> Void) {
        APIService.shared.addAccount(account: account)
            .sink(receiveCompletion: { [weak self] (completionStatus: Subscribers.Completion<Error>) in
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] (account: Account) in
                self?.fetchAccounts()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func updateAccount(id: Int, account: AccountSubmission, completion: @escaping (Bool) -> Void) {
        APIService.shared.updateAccount(accountId: id, updatedAccount: account)
            .sink(receiveCompletion: { [weak self] (completionStatus: Subscribers.Completion<Error>) in
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] (account: Account) in
                self?.fetchAccounts()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func deleteAccount(id: Int, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteAccount(accountId: id)
            .sink(receiveCompletion: { [weak self] (completionStatus: Subscribers.Completion<Error>) in
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] (response: MessageResponse) in
                self?.fetchAccounts()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Budget Management Methods
    func resetBalances(completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        APIService.shared.resetBalances()
            .sink(receiveCompletion: { [weak self] completionStatus in
                self?.isLoading = false
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] response in
                self?.accounts = response.accounts
                self?.incomeSchedules = response.income_schedules
                self?.transferSchedules = response.transfer_schedules
                self?.updateTransactionsFromAccounts()
                self?.updateBudgetItemsFromAccounts()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Schedule Execution Methods
    func executeAllIncomeSchedules(completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        APIService.shared.executeAllIncomeSchedules()
            .sink(receiveCompletion: { [weak self] (completionStatus: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] (response: IncomeExecutionResponse) in
                // Update accounts and fetch updated data
                self?.fetchData()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func executeAllTransferSchedules(completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        APIService.shared.executeAllTransferSchedules()
            .sink(receiveCompletion: { [weak self] (completionStatus: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] (response: TransferExecutionResponse) in
                // Update the accounts after execution
                if let accounts = response.accounts {
                    self?.accounts = accounts
                    self?.updateTransactionsFromAccounts()
                    self?.updateBudgetItemsFromAccounts()
                }
                
                // Fetch updated schedules
                self?.fetchTransferSchedules()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func executeIncomeSchedule(id: Int, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        APIService.shared.executeIncomeSchedule(scheduleId: id)
            .sink(receiveCompletion: { [weak self] (completionStatus: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] (response: MessageResponse) in
                // Refresh data after execution
                self?.fetchData()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func executeTransferSchedule(id: Int, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        APIService.shared.executeTransferSchedule(scheduleId: id)
            .sink(receiveCompletion: { [weak self] (completionStatus: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let err) = completionStatus {
                    self?.error = err.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] (response: TransferExecutionResponse) in
                if response.success == true {
                    // Update accounts if available
                    if let accounts = response.accounts {
                        self?.accounts = accounts
                    }
                    
                    // Fetch updated schedules
                    self?.fetchTransferSchedules()
                    self?.updateTransactionsFromAccounts()
                    self?.updateBudgetItemsFromAccounts()
                    completion(true)
                } else {
                    self?.error = response.error ?? "Unknown error during transfer execution"
                    completion(false)
                }
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Data Conversion Methods
    private func updateTransactionsFromAccounts() {
        var newTransactions: [Transaction] = []
        
        for account in accounts {
            // Add income transactions
            if let incomes = account.incomes {
                for income in incomes {
                    if let date = dateFromString(income.date) {
                        newTransactions.append(Transaction(
                            title: income.description,
                            amount: income.amount,
                            date: date,
                            category: .salary,
                            isIncome: true,
                            isPayment: false
                        ))
                    }
                }
            }
            
            // Add expense transactions
            if let expenses = account.expenses {
                for expense in expenses {
                    if let date = dateFromString(expense.date) {
                        newTransactions.append(Transaction(
                            title: expense.description,
                            amount: expense.amount,
                            date: date,
                            category: getCategoryForDescription(expense.description),
                            isIncome: false,
                            isPayment: false
                        ))
                    }
                }
            }
            
            // Add scheduled payments as transactions
            if let payments = account.scheduled_payments {
                for payment in payments {
                    if let date = dateFromString(payment.date) {
                        newTransactions.append(Transaction(
                            title: payment.name,
                            amount: payment.amount,
                            date: date,
                            category: getCategoryForDescription(payment.name),
                            isIncome: false,
                            isPayment: true
                        ))
                    }
                }
            }
            
            // Add scheduled payments from pots
            if let pots = account.pots {
                for pot in pots {
                    if let potPayments = pot.scheduled_payments {
                        for payment in potPayments {
                            if let date = dateFromString(payment.date) {
                                newTransactions.append(Transaction(
                                    title: "\(payment.name) (from \(pot.name))",
                                    amount: payment.amount,
                                    date: date,
                                    category: getCategoryForDescription(payment.name),
                                    isIncome: false,
                                    isPayment: true
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        print("Updated transactions with \(newTransactions.count) items from accounts")
        self.transactions = newTransactions
    }
    
    private func updateBudgetItemsFromAccounts() {
        var newBudgetItems: [BudgetItem] = []
        
        for account in accounts {
            if let pots = account.pots {
                for pot in pots {
                    if let payments = pot.scheduled_payments {
                        let allocated = payments.reduce(0) { $0 + $1.amount }
                        let category = determineCategoryFromPot(pot)
                        
                        newBudgetItems.append(BudgetItem(
                            category: category,
                            allocated: allocated,
                            spent: pot.balance
                        ))
                    }
                }
            }
        }
        
        print("Updated budget items with \(newBudgetItems.count) items from accounts")
        self.budgetItems = newBudgetItems
    }
    
    private func determineCategoryFromPot(_ pot: Pot) -> Category {
        let name = pot.name.lowercased()
        
        if name.contains("bill") {
            return .utilities
        } else if name.contains("food") || name.contains("grocer") {
            return .food
        } else if name.contains("transport") || name.contains("travel") || name.contains("car") {
            return .transport
        } else if name.contains("entertainment") || name.contains("fun") {
            return .entertainment
        } else if name.contains("health") || name.contains("medical") {
            return .health
        } else if name.contains("shop") {
            return .shopping
        } else {
            return .other
        }
    }
    
    // MARK: - Utility Methods
    private func dateFromString(_ dateString: String) -> Date? {
        // First try ISO8601 format (for full dates like "2025-02-10T13:02:00.257Z")
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // If that fails, try handling day-of-month strings like "1", "15", etc.
        if let dayOfMonth = Int(dateString) {
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            
            // Use current month and year, but specified day
            var components = calendar.dateComponents([.year, .month], from: Date())
            components.day = dayOfMonth
            
            // Create a date for the specified day of the current month
            return calendar.date(from: components)
        }
        
        // Fall back to today's date if all else fails
        return Date()
    }
    
    // Helper to determine category from transaction description
    private func getCategoryForDescription(_ description: String) -> Category {
        let text = description.lowercased()
        
        if text.contains("rent") || text.contains("bill") || text.contains("utility") || text.contains("electricity") || 
           text.contains("water") || text.contains("gas") || text.contains("internet") || text.contains("broadband") {
            return .utilities
        } else if text.contains("food") || text.contains("grocer") || text.contains("takeaway") || 
                  text.contains("restaurant") || text.contains("cafe") || text.contains("coffee") {
            return .food
        } else if text.contains("transport") || text.contains("travel") || text.contains("car") || 
                  text.contains("bus") || text.contains("train") || text.contains("taxi") || text.contains("uber") {
            return .transport
        } else if text.contains("entertainment") || text.contains("movie") || text.contains("netflix") || 
                  text.contains("spotify") || text.contains("cinema") || text.contains("subscription") {
            return .entertainment
        } else if text.contains("health") || text.contains("medical") || text.contains("doctor") || 
                  text.contains("pharmacy") || text.contains("medicine") || text.contains("gym") {
            return .health
        } else if text.contains("shop") || text.contains("amazon") || text.contains("purchase") || 
                  text.contains("store") || text.contains("buy") {
            return .shopping
        } else if text.contains("salary") || text.contains("wage") || text.contains("income") || 
                  text.contains("dividend") || text.contains("payment") {
            return .salary
        } else {
            return .other
        }
    }
}
