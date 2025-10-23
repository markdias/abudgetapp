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
                Section("Expense") {
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

struct TransferComposerView: View {
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var potsStore: PotsStore
    @EnvironmentObject private var transferStore: TransferSchedulesStore
    @Binding var isPresented: Bool

    @State private var fromAccountId: Int?
    @State private var fromPotName: String = ""
    @State private var toAccountId: Int?
    @State private var toPotName: String = ""
    @State private var amount = ""
    @State private var description = ""
    @State private var isDirectPotTransfer = false

    private var destinationAccounts: [Account] {
        accountsStore.accounts.filter { account in
            if let pots = potsStore.potsByAccount[account.id] {
                return !pots.isEmpty
            }
            return !(account.pots?.isEmpty ?? true)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From") {
                    Picker("Account", selection: $fromAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(accountsStore.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                    if let accountId = fromAccountId, let pots = potsStore.potsByAccount[accountId], !pots.isEmpty {
                        Picker("Pot", selection: $fromPotName) {
                            Text("None").tag("")
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name)
                            }
                        }
                    }
                }
                Section("To") {
                    if destinationAccounts.isEmpty {
                        Text("Add a pot to an account before scheduling a transfer destination.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Account", selection: $toAccountId) {
                            Text("Select Account").tag(nil as Int?)
                            ForEach(destinationAccounts) { account in
                                Text(account.name).tag(account.id as Int?)
                            }
                        }
                        if let accountId = toAccountId {
                            let pots = potsStore.potsByAccount[accountId] ?? accountsStore.account(for: accountId)?.pots ?? []
                            if !pots.isEmpty {
                            Picker("Pot", selection: $toPotName) {
                                ForEach(pots, id: \.name) { pot in
                                    Text(pot.name).tag(pot.name)
                                }
                            }
                            }
                        }
                    }
                }
                Section("Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Description", text: $description)
                    Toggle("Direct Pot Transfer", isOn: $isDirectPotTransfer)
                }
            }
            .navigationTitle("Transfer Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save", action: save).disabled(!isValid) }
            }
            .onChange(of: toAccountId) { newValue in
                guard let id = newValue else {
                    toPotName = ""
                    return
                }
                let pots = potsStore.potsByAccount[id] ?? accountsStore.account(for: id)?.pots ?? []
                guard !pots.isEmpty else {
                    toPotName = ""
                    return
                }
                if !pots.contains(where: { $0.name == toPotName }) {
                    toPotName = pots.first?.name ?? ""
                }
            }
            .onAppear {
                if toAccountId == nil, let firstAccount = destinationAccounts.first {
                    toAccountId = firstAccount.id
                }
                guard let id = toAccountId else {
                    toPotName = ""
                    return
                }
                let pots = potsStore.potsByAccount[id] ?? accountsStore.account(for: id)?.pots ?? []
                guard !pots.isEmpty else {
                    toPotName = ""
                    return
                }
                if toPotName.isEmpty || !pots.contains(where: { $0.name == toPotName }) {
                    toPotName = pots.first?.name ?? ""
                }
            }
        }
    }

    private var isValid: Bool {
        guard let toAccountId = toAccountId,
              let amountValue = Double(amount),
              amountValue > 0 else { return false }
        if fromAccountId == nil && fromPotName.isEmpty { return false }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPot = toPotName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty, !trimmedPot.isEmpty else { return false }
        guard destinationAccounts.contains(where: { $0.id == toAccountId }) else { return false }
        let availablePots = potsStore.potsByAccount[toAccountId] ?? accountsStore.account(for: toAccountId)?.pots ?? []
        guard !availablePots.isEmpty else { return false }
        return true
    }

    private func save() {
        guard let toAccountId = toAccountId,
              let amountValue = Double(amount) else { return }
        let trimmedPotName = toPotName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPotName.isEmpty, !trimmedDescription.isEmpty else { return }
        let submission = TransferScheduleSubmission(
            fromAccountId: fromAccountId,
            fromPotId: fromPotName.isEmpty ? nil : fromPotName,
            toAccountId: toAccountId,
            toPotName: trimmedPotName,
            amount: amountValue,
            description: trimmedDescription,
            items: nil,
            isDirectPotTransfer: isDirectPotTransfer
        )
        Task {
            await transferStore.add(submission)
            isPresented = false
        }
    }
}
