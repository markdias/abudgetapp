import Foundation

@MainActor
final class ScheduledPaymentsStore: ObservableObject {
    struct ScheduledPaymentContext: Identifiable, Hashable {
        let id: String
        let accountId: Int
        let accountName: String
        let potName: String?
        let payment: ScheduledPayment

        init(accountId: Int, accountName: String, potName: String?, payment: ScheduledPayment) {
            self.accountId = accountId
            self.accountName = accountName
            self.potName = potName
            self.payment = payment
            self.id = "\(accountId)-\(potName ?? "account")-\(payment.id)"
        }
    }

    @Published private(set) var items: [ScheduledPaymentContext] = []
    @Published var lastMessage: StatusMessage?
    @Published var lastError: APIServiceError?

    private let service: APIServiceProtocol
    private unowned let accountsStore: AccountsStore
    private var accountsObserver: NSObjectProtocol?

    init(accountsStore: AccountsStore, service: APIServiceProtocol = APIService.shared) {
        self.accountsStore = accountsStore
        self.service = service
        self.items = Self.buildContexts(from: accountsStore.accounts)
        accountsObserver = NotificationCenter.default.addObserver(
            forName: AccountsStore.accountsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let accounts = notification.userInfo?["accounts"] as? [Account] else { return }
            let contexts = Self.buildContexts(from: accounts)
            Task { @MainActor in
                self.items = contexts
            }
        }
    }

    deinit {
        if let observer = accountsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func addPayment(accountId: Int, submission: ScheduledPaymentSubmission, potName: String? = nil) async {
        do {
            let payment = try await service.addScheduledPayment(accountId: accountId, potName: potName, payment: submission)
            accountsStore.mutateAccount(id: accountId) { account in
                if potName == nil {
                    var payments = account.scheduled_payments ?? []
                    payments.append(payment)
                    account.scheduled_payments = payments
                } else {
                    guard var pots = account.pots else { return }
                    if let index = pots.firstIndex(where: { $0.name == potName }) {
                        var pot = pots[index]
                        var payments = pot.scheduled_payments ?? []
                        payments.append(payment)
                        pot.scheduled_payments = payments
                        pots[index] = pot
                        account.pots = pots
                    }
                }
            }
            lastMessage = StatusMessage(title: "Scheduled", message: "Scheduled \(payment.name)", kind: .success)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Schedule Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Schedule Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    func deletePayment(context: ScheduledPaymentContext) async {
        do {
            _ = try await service.deleteScheduledPayment(
                accountId: context.accountId,
                paymentName: context.payment.name,
                paymentDate: context.payment.date,
                potName: context.potName
            )
            accountsStore.mutateAccount(id: context.accountId) { account in
                if let potName = context.potName {
                    guard var pots = account.pots else { return }
                    if let index = pots.firstIndex(where: { $0.name == potName }) {
                        var pot = pots[index]
                        pot.scheduled_payments?.removeAll { $0.id == context.payment.id }
                        pots[index] = pot
                        account.pots = pots
                    }
                } else {
                    account.scheduled_payments?.removeAll { $0.id == context.payment.id }
                }
            }
            lastMessage = StatusMessage(title: "Scheduled", message: "Deleted \(context.payment.name)", kind: .warning)
        } catch let error as APIServiceError {
            lastError = error
            lastMessage = StatusMessage(title: "Delete Failed", message: error.localizedDescription, kind: .error)
        } catch {
            let apiError = APIServiceError.unknown(error)
            lastError = apiError
            lastMessage = StatusMessage(title: "Delete Failed", message: apiError.localizedDescription, kind: .error)
        }
    }

    private nonisolated static func buildContexts(from accounts: [Account]) -> [ScheduledPaymentContext] {
        var contexts: [ScheduledPaymentContext] = []
        for account in accounts {
            if let payments = account.scheduled_payments {
                for payment in payments {
                    contexts.append(ScheduledPaymentContext(accountId: account.id, accountName: account.name, potName: nil, payment: payment))
                }
            }
            if let pots = account.pots {
                for pot in pots {
                    if let payments = pot.scheduled_payments {
                        for payment in payments {
                            contexts.append(ScheduledPaymentContext(accountId: account.id, accountName: account.name, potName: pot.name, payment: payment))
                        }
                    }
                }
            }
        }
        contexts.sort { $0.payment.date < $1.payment.date }
        return contexts
    }
}
