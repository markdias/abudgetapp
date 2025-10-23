import Foundation

@MainActor
final class PotsStore: ObservableObject {
    @Published private(set) var potsByAccount: [Int: [Pot]] = [:]
    @Published var lastMessage: StatusMessage?
    @Published var lastError: APIServiceError?

    private let service: APIServiceProtocol
    private unowned let accountsStore: AccountsStore
    private var accountsObserver: NSObjectProtocol?

    init(accountsStore: AccountsStore, service: APIServiceProtocol = APIService.shared) {
        self.accountsStore = accountsStore
        self.service = service
        self.potsByAccount = Self.buildMap(from: accountsStore.accounts)
        observeAccountChanges()
    }

    deinit {
        if let observer = accountsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func addPot(to accountId: Int, submission: PotSubmission) async {
        do {
            let pot = try await service.addPot(accountId: accountId, pot: submission)
            updateLocalPot(accountId: accountId) { pots in
                pots.append(pot)
            }
            accountsStore.mutateAccount(id: accountId) { account in
                var pots = account.pots ?? []
                pots.append(pot)
                account.pots = pots
            }
            lastMessage = StatusMessage(title: "Pot Added", message: "Added \(pot.name)", kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Pot Error", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Pot Error", message: apiError.localizedDescription, kind: .error)
        }
    }

    func updatePot(accountId: Int, existingPot: Pot, submission: PotSubmission) async {
        do {
            let updated = try await service.updatePot(originalAccountId: accountId, originalPot: existingPot, updatedPot: submission)
            updateLocalPot(accountId: accountId) { pots in
                if let index = pots.firstIndex(where: { $0.id == updated.id }) {
                    pots[index] = updated
                }
            }
            accountsStore.mutateAccount(id: accountId) { account in
                guard var pots = account.pots else { return }
                if let index = pots.firstIndex(where: { $0.id == updated.id }) {
                    pots[index] = updated
                    account.pots = pots
                }
            }
            lastMessage = StatusMessage(title: "Pot Updated", message: "Updated \(updated.name)", kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Pot Update Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Pot Update Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func deletePot(accountId: Int, potName: String) async {
        guard let account = accountsStore.account(for: accountId) else { return }
        do {
            _ = try await service.deletePot(accountName: account.name, potName: potName)
            updateLocalPot(accountId: accountId) { pots in
                pots.removeAll { $0.name == potName }
            }
            accountsStore.mutateAccount(id: accountId) { account in
                account.pots?.removeAll { $0.name == potName }
            }
            lastMessage = StatusMessage(title: "Pot Deleted", message: "Removed \(potName)", kind: .warning)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Delete Pot Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Delete Pot Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func toggleExclusion(accountId: Int, potName: String) async {
        do {
            let response = try await service.togglePotExclusion(accountId: accountId, potName: potName)
            updateLocalPot(accountId: accountId) { pots in
                if let index = pots.firstIndex(where: { $0.name == potName }) {
                    pots[index].excludeFromReset = response.excludeFromReset
                }
            }
            accountsStore.mutateAccount(id: accountId) { account in
                guard var pots = account.pots else { return }
                if let index = pots.firstIndex(where: { $0.name == potName }) {
                    pots[index].excludeFromReset = response.excludeFromReset
                    account.pots = pots
                }
            }
            let status: StatusMessage.Kind = response.excludeFromReset ? .info : .success
            lastMessage = StatusMessage(title: "Pot Updated", message: response.excludeFromReset ? "Excluded from reset" : "Included in reset", kind: status)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Exclusion Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Exclusion Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    private func observeAccountChanges() {
        accountsObserver = NotificationCenter.default.addObserver(
            forName: AccountsStore.accountsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let accounts = notification.userInfo?["accounts"] as? [Account] {
                let mapping = Self.buildMap(from: accounts)
                Task { @MainActor in
                    self.potsByAccount = mapping
                }
            }
        }
    }

    private func updateLocalPot(accountId: Int, mutate: (inout [Pot]) -> Void) {
        var pots = potsByAccount[accountId] ?? []
        mutate(&pots)
        potsByAccount[accountId] = pots
    }

    private nonisolated static func buildMap(from accounts: [Account]) -> [Int: [Pot]] {
        var mapping: [Int: [Pot]] = [:]
        for account in accounts {
            mapping[account.id] = account.pots ?? []
        }
        return mapping
    }
}
