import Foundation

@MainActor
final class SavingsInvestmentsStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published var isLoading = false
    @Published var lastMessage: StatusMessage?
    @Published var lastError: BudgetDataError?

    private let store: LocalBudgetStore

    init(store: LocalBudgetStore = .shared) {
        self.store = store
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        accounts = await store.savingsAndInvestments()
    }

    func toggleExclusion(accountId: Int) async {
        do {
            let exclude = try await store.toggleAccountExclusion(accountId: accountId)
            if let index = accounts.firstIndex(where: { $0.id == accountId }) {
                accounts[index].excludeFromReset = exclude
            }
            let message = exclude ? "Excluded from reset" : "Included in reset"
            let kind: StatusMessage.Kind = exclude ? .info : .success
            lastMessage = StatusMessage(title: "Savings", message: message, kind: kind)
        } catch let error as LocalBudgetStore.StoreError {
            let dataError = error.asBudgetDataError
            lastError = dataError
            lastMessage = StatusMessage(title: "Toggle Failed", message: dataError.localizedDescription, kind: .error)
        } catch {
            let dataError = BudgetDataError.unknown(error)
            lastError = dataError
            lastMessage = StatusMessage(title: "Toggle Failed", message: dataError.localizedDescription, kind: .error)
        }
    }

    var totalBalance: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }
}
