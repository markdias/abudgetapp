import SwiftUI

struct AccountFormView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var balance = "0"
    @State private var type = "current"
    @State private var accountType = "personal"
    @State private var creditLimit = ""
    @State private var isSaving = false

    private let accountTypes = ["current", "credit", "savings", "investment"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Starting Balance", text: $balance)
                        .keyboardType(.decimalPad)
                    Picker("Type", selection: $type) {
                        ForEach(accountTypes, id: \.self) { value in
                            Text(value.capitalized).tag(value)
                        }
                    }
                    TextField("Account Category", text: $accountType)
                    if type == "credit" {
                        TextField("Credit Limit", text: $creditLimit)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard !name.isEmpty, Double(balance) != nil else { return false }
        if type == "credit" { return Double(creditLimit) != nil }
        return true
    }

    private func save() {
        guard let startingBalance = Double(balance) else { return }
        let limit = Double(creditLimit)
        let submission = AccountSubmission(
            name: name,
            balance: startingBalance,
            type: type,
            accountType: accountType,
            credit_limit: limit
        )
        Task {
            await accountsStore.addAccount(submission)
            isPresented = false
        }
    }
}

struct PotFormView: View {
    @EnvironmentObject private var potsStore: PotsStore
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    @State private var selectedAccountId: Int?
    @State private var name = ""
    @State private var balance = "0"

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: $selectedAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Balance", text: $balance)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Pot")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save", action: save).disabled(!isValid) }
            }
        }
    }

    private var isValid: Bool {
        selectedAccountId != nil && !name.isEmpty && Double(balance) != nil
    }

    private func save() {
        guard let accountId = selectedAccountId, let amount = Double(balance) else { return }
        let submission = PotSubmission(name: name, balance: amount)
        Task {
            await potsStore.addPot(to: accountId, submission: submission)
            isPresented = false
        }
    }
}

struct IncomeFormView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    @State private var selectedAccountId: Int?
    @State private var amount = "0"
    @State private var description = ""
    @State private var company = ""
    @State private var dayOfMonth = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: $selectedAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }
                Section("Income") {
                    TextField("Description", text: $description)
                    TextField("Company", text: $company)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Income")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save", action: save).disabled(!isValid) }
            }
        }
    }

    private var isValid: Bool {
        selectedAccountId != nil && !description.isEmpty && !company.isEmpty && Double(amount) != nil && validDay
    }

    private var validDay: Bool {
        if let d = Int(dayOfMonth), (1...31).contains(d) { return true }
        return false
    }

    private func save() {
        guard let accountId = selectedAccountId, let money = Double(amount) else { return }
        let submission = IncomeSubmission(amount: money, description: description, company: company, date: dayOfMonth)
        Task {
            await accountsStore.addIncome(accountId: accountId, submission: submission)
            isPresented = false
        }
    }
}

struct ExpenseFormView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    @State private var selectedAccountId: Int?
    @State private var amount = "0"
    @State private var description = ""
    @State private var dayOfMonth = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: $selectedAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }
                Section(header: Text("Expense"), footer: Text("Expenses stay within the main account balance and never move money into pots.")) {
                    TextField("Description", text: $description)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save", action: save).disabled(!isValid) }
            }
        }
    }

    private var isValid: Bool {
        selectedAccountId != nil && !description.isEmpty && Double(amount) != nil && validDay
    }

    private var validDay: Bool {
        if let d = Int(dayOfMonth), (1...31).contains(d) { return true }
        return false
    }

    private func save() {
        guard let accountId = selectedAccountId, let money = Double(amount) else { return }
        let submission = ExpenseSubmission(amount: money, description: description, date: dayOfMonth)
        Task {
            await accountsStore.addExpense(accountId: accountId, submission: submission)
            isPresented = false
        }
    }
}


struct TransactionFormView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    @State private var selectedAccountId: Int?
    @State private var amount = "0"
    @State private var description = ""
    @State private var merchant = ""
    @State private var dayOfMonth = ""
    @State private var isCredit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: $selectedAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }
                Section("Transaction") {
                    TextField("Description", text: $description)
                    TextField("Merchant", text: $merchant)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Toggle("Credit (adds to balance)", isOn: $isCredit)
                    TextField("Day of Month (1-31)", text: $dayOfMonth)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save", action: save).disabled(!isValid) }
            }
        }
    }

    private var isValid: Bool {
        selectedAccountId != nil && !description.isEmpty && Double(amount) != nil && validDay
    }

    private var validDay: Bool {
        if let d = Int(dayOfMonth), (1...31).contains(d) { return true }
        return false
    }

    private func save() {
        guard let accountId = selectedAccountId, let money = Double(amount) else { return }
        let submission = TransactionSubmission(
            amount: money,
            description: description,
            date: dayOfMonth,
            merchant: merchant.isEmpty ? nil : merchant,
            isCredit: isCredit
        )
        Task {
            await accountsStore.addTransaction(accountId: accountId, submission: submission)
            isPresented = false
        }
    }
}
