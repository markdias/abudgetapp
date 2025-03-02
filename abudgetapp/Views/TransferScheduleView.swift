import SwiftUI

struct TransferScheduleView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddSchedule = false
    @State private var isLoading = false
    @State private var selectedSchedule: TransferSchedule?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(appState.transferSchedules) { schedule in
                    TransferScheduleRow(schedule: schedule) {
                        executeSchedule(schedule)
                    }
                }
            }
            .navigationTitle("Transfer Schedules")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSchedule = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: executeAllSchedules) {
                        Text("Execute All")
                    }
                    .disabled(appState.transferSchedules.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                AddTransferScheduleView(isPresented: $showingAddSchedule)
            }
            .refreshable {
                await loadTransferSchedules()
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.2))
                    }
                }
            )
        }
    }
    
    private func loadTransferSchedules() async {
        appState.fetchTransferSchedules()
    }
    
    private func executeSchedule(_ schedule: TransferSchedule) {
        isLoading = true
        appState.executeTransferSchedule(id: schedule.id) { success in
            isLoading = false
            if !success {
                // Handle error if needed
            }
        }
    }
    
    private func executeAllSchedules() {
        isLoading = true
        appState.executeAllTransferSchedules { success in
            isLoading = false
            if !success {
                // Handle error if needed
            }
        }
    }
}

struct TransferScheduleRow: View {
    let schedule: TransferSchedule
    let onExecute: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.description)
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.2f", schedule.amount))
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let fromPotId = schedule.fromPotId {
                        Text("From: \(fromPotId)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let fromAccountId = schedule.fromAccountId {
                        Text("From Account: \(fromAccountId)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let toPotName = schedule.toPotName {
                        Text("To: \(toPotName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("To Account: \(schedule.toAccountId)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onExecute) {
                    Text("Execute")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            if let items = schedule.items, !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(items, id: \.description) { item in
                        HStack {
                            Text("• \(item.description)")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "$%.2f", item.amount))
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct TransferItemForm: Identifiable {
    let id = UUID()
    var description: String
    var amount: Double
    
    func toTransferItem() -> TransferItem {
        TransferItem(amount: amount, description: description)
    }
}

struct AddTransferScheduleView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var fromAccountId: Int?
    @State private var fromPotId: String = ""
    @State private var toAccountId: Int?
    @State private var toPotName: String = ""
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var isDirectPotTransfer: Bool = false
    @State private var items: [TransferItemForm] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("From")) {
                    Picker("Account", selection: $fromAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(appState.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                    
                    if let selectedAccount = appState.accounts.first(where: { $0.id == fromAccountId }),
                       let pots = selectedAccount.pots {
                        Picker("Pot", selection: $fromPotId) {
                            Text("Select Pot").tag("")
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name)
                            }
                        }
                    }
                }
                
                Section(header: Text("To")) {
                    Picker("Account", selection: $toAccountId) {
                        Text("Select Account").tag(nil as Int?)
                        ForEach(appState.accounts) { account in
                            Text(account.name).tag(account.id as Int?)
                        }
                    }
                    
                    if let selectedAccount = appState.accounts.first(where: { $0.id == toAccountId }),
                       let pots = selectedAccount.pots {
                        Picker("Pot", selection: $toPotName) {
                            Text("Select Pot").tag("")
                            ForEach(pots, id: \.name) { pot in
                                Text(pot.name).tag(pot.name)
                            }
                        }
                    }
                }
                
                Section(header: Text("Details")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Description", text: $description)
                    
                    Toggle("Direct Pot Transfer", isOn: $isDirectPotTransfer)
                }
                
                Section(header: Text("Items")) {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                TextField("Description", text: Binding(
                                    get: { item.description },
                                    set: { newValue in
                                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                                            items[index].description = newValue
                                        }
                                    }
                                ))
                                TextField("Amount", value: Binding(
                                    get: { item.amount },
                                    set: { newValue in
                                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                                            items[index].amount = newValue
                                        }
                                    }
                                ), formatter: NumberFormatter())
                                    .keyboardType(.decimalPad)
                            }
                            
                            Button(action: {
                                items.removeAll(where: { $0.id == item.id })
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button("Add Item") {
                        items.append(TransferItemForm(description: "", amount: 0))
                    }
                }
            }
            .navigationTitle("New Transfer Schedule")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    Task {
                        await saveTransferSchedule()
                    }
                }
                .disabled(!isValid || isLoading)
            )
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.2))
                    }
                }
            )
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        guard !description.isEmpty,
              let amountValue = Double(amount),
              amountValue > 0,
              toAccountId != nil else {
            return false
        }
        return true
    }
    
    private func saveTransferSchedule() async {
        guard let amountValue = Double(amount) else { return }
        
        isLoading = true
        
        let submission = TransferScheduleSubmission(
            fromAccountId: fromAccountId,
            fromPotId: fromPotId.isEmpty ? nil : fromPotId,
            toAccountId: toAccountId ?? 0,
            toPotName: toPotName.isEmpty ? nil : toPotName,
            amount: amountValue,
            description: description,
            items: items.map { $0.toTransferItem() },
            isDirectPotTransfer: isDirectPotTransfer
        )
        
        do {
            let success = try await appState.addTransferSchedule(submission)
            if success {
                isPresented = false
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

struct TransferScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        TransferScheduleView()
            .environmentObject(AppState())
    }
}
