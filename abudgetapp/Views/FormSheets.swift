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

// Income, Expense, and Transaction forms removed
