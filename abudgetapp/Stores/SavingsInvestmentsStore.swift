import Foundation

@MainActor
final class SavingsInvestmentsStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published var isLoading = false
    @Published var lastMessage: StatusMessage?
    @Published var lastError: APIServiceError?

    private let service: APIServiceProtocol

    init(service: APIServiceProtocol = APIService.shared) {
        self.service = service
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await service.getSavingsInvestments()
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Savings", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Savings", message: apiError.localizedDescription, kind: .error)
        }
    }

    func toggleExclusion(accountId: Int) async {
        do {
            let response = try await service.toggleAccountExclusion(accountId: accountId)
            if let index = accounts.firstIndex(where: { $0.id == accountId }) {
                accounts[index].excludeFromReset = response.excludeFromReset
            }
            let message = response.excludeFromReset ? "Excluded from reset" : "Included in reset"
            let kind: StatusMessage.Kind = response.excludeFromReset ? .info : .success
            lastMessage = StatusMessage(title: "Savings", message: message, kind: kind)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Toggle Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Toggle Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    var totalBalance: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }
}
