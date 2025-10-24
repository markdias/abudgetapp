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
    @State private var name = ""
    @State private var company = ""
    @State private var dayOfMonth = ""
    @State private var selectedPotName: String? = nil

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
                if let account = accountsStore.accounts.first(where: { $0.id == selectedAccountId }), let pots = account.pots, !pots.isEmpty {
                    Section("Pot") {
                        Picker("Deposit to Pot", selection: $selectedPotName) {
                            Text("None").tag(nil as String?)
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name as String?)
                            }
                        }
                    }
                }
                Section("Income Details") {
                    TextField("Name", text: $name)
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
            .onChange(of: selectedAccountId) { _, _ in
                selectedPotName = nil
            }
        }
    }

    private var isValid: Bool {
        selectedAccountId != nil && !name.isEmpty && !company.isEmpty && Double(amount) != nil && validDay
    }

    private var validDay: Bool {
        if let d = Int(dayOfMonth), (1...31).contains(d) { return true }
        return false
    }

    private func save() {
        guard let accountId = selectedAccountId, let money = Double(amount) else { return }
        let submission = IncomeSubmission(amount: money, description: name, company: company, date: dayOfMonth, potName: selectedPotName)
        Task {
            await accountsStore.addIncome(accountId: accountId, submission: submission)
            isPresented = false
        }
    }
}

struct ExpenseFormView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    @State private var fromAccountId: Int?
    @State private var toAccountId: Int?
    @State private var amount = "0"
    @State private var name = ""
    @State private var dayOfMonth = ""
    @State private var selectedPotName: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("From Account") {
                    Picker("Account", selection: $fromAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }
                Section("To Account") {
                    Picker("Account", selection: $toAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                    if let pots = accountsStore.accounts.first(where: { $0.id == toAccountId })?.pots, !pots.isEmpty {
                        Picker("Pot", selection: $selectedPotName) {
                            Text("None").tag(nil as String?)
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name as String?)
                            }
                        }
                    }
                }
                Section("Expense Details") {
                    TextField("Name", text: $name)
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
            .onChange(of: toAccountId) { _, _ in
                selectedPotName = nil
            }
        }
    }

    private var isValid: Bool {
        fromAccountId != nil && toAccountId != nil && !name.isEmpty && Double(amount) != nil && validDay
    }

    private var validDay: Bool {
        if let d = Int(dayOfMonth), (1...31).contains(d) { return true }
        return false
    }

    private func save() {
        guard let fromAccountId, let toAccountId, let money = Double(amount) else { return }
        let submission = ExpenseSubmission(amount: money, description: name, date: dayOfMonth, toAccountId: toAccountId, toPotName: selectedPotName)
        Task {
            await accountsStore.addExpense(accountId: fromAccountId, submission: submission)
            isPresented = false
        }
    }
}

struct TransactionFormView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @Binding var isPresented: Bool

    @State private var fromAccountId: Int?
    @State private var toAccountId: Int?
    @State private var selectedPotName: String? = nil
    @State private var name = ""
    @State private var vendor = ""
    @State private var amount = "0"
    @State private var dayOfMonth = ""

    init(isPresented: Binding<Bool>, defaultFromAccountId: Int? = nil) {
        self._isPresented = isPresented
        self._fromAccountId = State(initialValue: defaultFromAccountId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From Account") {
                    Picker("Account", selection: $fromAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                }

                Section("To Account") {
                    Picker("Account", selection: $toAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                    if let pots = accountsStore.accounts.first(where: { $0.id == toAccountId })?.pots, !pots.isEmpty {
                        Picker("Pot", selection: $selectedPotName) {
                            Text("None").tag(nil as String?)
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name as String?)
                            }
                        }
                    }
                }

                Section("Transaction Details") {
                    TextField("Name", text: $name)
                    TextField("Vendor", text: $vendor)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    TextField("Day of Month (1-31)", text: $dayOfMonth).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save", action: save).disabled(!isValid) }
            }
            .onChange(of: toAccountId) { _, _ in selectedPotName = nil }
        }
    }

    private var isValid: Bool {
        guard let fromAccountId, let toAccountId, !name.isEmpty, !vendor.isEmpty, let money = Double(amount), money > 0 else { return false }
        if let day = Int(dayOfMonth), (1...31).contains(day) {
            return true
        }
        return false
    }

    private func save() {
        guard let fromAccountId, let toAccountId, let money = Double(amount) else { return }
        let submission = TransactionSubmission(
            name: name,
            vendor: vendor,
            amount: money,
            date: dayOfMonth.isEmpty ? nil : dayOfMonth,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            toPotName: selectedPotName
        )
        Task {
            await accountsStore.addTransaction(submission)
            isPresented = false
        }
    }
}

