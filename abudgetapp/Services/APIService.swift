import Foundation

protocol APIServiceProtocol {
    func getAccounts() async throws -> [Account]
    func addAccount(account: AccountSubmission) async throws -> Account
    func updateAccount(accountId: Int, updatedAccount: AccountSubmission) async throws -> Account
    func deleteAccount(accountId: Int) async throws -> MessageResponse
    func updateCardOrder(accountIds: [Int]) async throws -> CardOrderResponse

    func addPot(accountId: Int, pot: PotSubmission) async throws -> Pot
    func updatePot(originalAccountId: Int, originalPot: Pot, updatedPot: PotSubmission) async throws -> Pot
    func deletePot(accountName: String, potName: String) async throws -> MessageResponse

    func addExpense(accountId: Int, expense: ExpenseSubmission) async throws -> Expense
    func addIncome(accountId: Int, income: IncomeSubmission) async throws -> Income
    func deleteExpense(accountId: Int, expenseId: Int) async throws -> MessageResponse
    func deleteIncome(accountId: Int, incomeId: Int) async throws -> MessageResponse

    func addScheduledPayment(accountId: Int, payment: ScheduledPaymentSubmission) async throws -> ScheduledPayment
    func deleteScheduledPayment(accountId: Int, paymentName: String, paymentDate: String, potName: String?) async throws -> MessageResponse

    func resetBalances() async throws -> ResetResponse
    func toggleAccountExclusion(accountId: Int) async throws -> ExclusionResponse
    func togglePotExclusion(accountId: Int, potName: String) async throws -> ExclusionResponse

    func getSavingsInvestments() async throws -> [Account]

    func getTransferSchedules() async throws -> [TransferSchedule]
    func addTransferSchedule(transfer: TransferScheduleSubmission) async throws -> TransferSchedule
    func executeTransferSchedule(scheduleId: Int) async throws -> TransferExecutionResponse
    func executeAllTransferSchedules() async throws -> TransferExecutionResponse
    func deleteTransferSchedule(scheduleId: Int) async throws -> MessageResponse

    func getIncomeSchedules() async throws -> [IncomeSchedule]
    func addIncomeSchedule(schedule: IncomeScheduleSubmission) async throws -> IncomeSchedule
    func executeIncomeSchedule(scheduleId: Int) async throws -> MessageResponse
    func executeAllIncomeSchedules() async throws -> IncomeExecutionResponse
    func deleteIncomeSchedule(scheduleId: Int) async throws -> MessageResponse

    func getAvailableTransfers() async throws -> AvailableTransfers

    func updateBaseURL(_ newURL: String)
    func loadSavedURL() -> String
}

enum APIServiceError: LocalizedError, Equatable {
    case invalidBaseURL(String)
    case invalidEndpoint(String)
    case invalidResponse
    case server(code: Int, message: String?)
    case decoding(DecodingError)
    case transport(URLError)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "Invalid API base URL: \(value)"
        case .invalidEndpoint(let value):
            return "Invalid endpoint path: \(value)"
        case .invalidResponse:
            return "Received an unexpected response from the server"
        case .server(let code, let message):
            return message ?? "Server returned status code \(code)"
        case .decoding(let decodingError):
            return "Failed to decode response: \(decodingError.localizedDescription)"
        case .transport(let urlError):
            return urlError.localizedDescription
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

final class APIService: APIServiceProtocol {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public API Methods

    func getAccounts() async throws -> [Account] {
        try await request(endpoint: "/accounts")
    }

    func addAccount(account: AccountSubmission) async throws -> Account {
        try await request(endpoint: "/add-account", method: .post, body: account)
    }

    func updateAccount(accountId: Int, updatedAccount: AccountSubmission) async throws -> Account {
        let payload = UpdateAccountPayload(accountId: accountId, updatedAccount: updatedAccount)
        return try await request(endpoint: "/update-account", method: .put, body: payload)
    }

    func deleteAccount(accountId: Int) async throws -> MessageResponse {
        try await request(endpoint: "/delete-account", method: .delete, body: AccountIdPayload(accountId: accountId))
    }

    func updateCardOrder(accountIds: [Int]) async throws -> CardOrderResponse {
        try await request(endpoint: "/update-card-order", method: .post, body: CardOrderPayload(cardIds: accountIds))
    }

    func addPot(accountId: Int, pot: PotSubmission) async throws -> Pot {
        try await request(endpoint: "/add-pot", method: .post, body: AddPotPayload(accountId: accountId, pot: pot))
    }

    func updatePot(originalAccountId: Int, originalPot: Pot, updatedPot: PotSubmission) async throws -> Pot {
        let payload = UpdatePotPayload(originalAccountId: originalAccountId, originalPot: originalPot, updatedPot: updatedPot)
        return try await request(endpoint: "/update-pot", method: .put, body: payload)
    }

    func deletePot(accountName: String, potName: String) async throws -> MessageResponse {
        let payload = DeletePotPayload(accountName: accountName, potName: potName)
        return try await request(endpoint: "/delete-pot", method: .delete, body: payload)
    }

    func addExpense(accountId: Int, expense: ExpenseSubmission) async throws -> Expense {
        try await request(endpoint: "/add-expense", method: .post, body: AddExpensePayload(accountId: accountId, expense: expense))
    }

    func addIncome(accountId: Int, income: IncomeSubmission) async throws -> Income {
        try await request(endpoint: "/add-income", method: .post, body: AddIncomePayload(accountId: accountId, income: income))
    }

    func deleteExpense(accountId: Int, expenseId: Int) async throws -> MessageResponse {
        let payload = DeleteExpensePayload(accountId: accountId, expenseId: expenseId)
        return try await request(endpoint: "/delete-expense", method: .delete, body: payload)
    }

    func deleteIncome(accountId: Int, incomeId: Int) async throws -> MessageResponse {
        let payload = DeleteIncomePayload(accountId: accountId, incomeId: incomeId)
        return try await request(endpoint: "/delete-income", method: .delete, body: payload)
    }

    func addScheduledPayment(accountId: Int, payment: ScheduledPaymentSubmission) async throws -> ScheduledPayment {
        let payload = AddScheduledPaymentPayload(accountId: accountId, payment: payment)
        return try await request(endpoint: "/add-scheduled-payment", method: .post, body: payload)
    }

    func deleteScheduledPayment(accountId: Int, paymentName: String, paymentDate: String, potName: String?) async throws -> MessageResponse {
        let payload = DeleteScheduledPaymentPayload(accountId: accountId, paymentName: paymentName, paymentDate: paymentDate, potName: potName)
        return try await request(endpoint: "/delete-scheduled-payment", method: .delete, body: payload)
    }

    func resetBalances() async throws -> ResetResponse {
        try await request(endpoint: "/reset-balances", method: .post, body: EmptyPayload())
    }

    func toggleAccountExclusion(accountId: Int) async throws -> ExclusionResponse {
        try await request(endpoint: "/toggle-account-exclusion", method: .post, body: AccountIdPayload(accountId: accountId))
    }

    func togglePotExclusion(accountId: Int, potName: String) async throws -> ExclusionResponse {
        let payload = TogglePotExclusionPayload(accountId: accountId, potName: potName)
        return try await request(endpoint: "/toggle-pot-exclusion", method: .post, body: payload)
    }

    func getSavingsInvestments() async throws -> [Account] {
        try await request(endpoint: "/savings-investments")
    }

    func getTransferSchedules() async throws -> [TransferSchedule] {
        try await request(endpoint: "/transfer-schedules")
    }

    func addTransferSchedule(transfer: TransferScheduleSubmission) async throws -> TransferSchedule {
        try await request(endpoint: "/add-transfer-schedule", method: .post, body: transfer)
    }

    func executeTransferSchedule(scheduleId: Int) async throws -> TransferExecutionResponse {
        try await request(endpoint: "/execute-transfer-schedule", method: .post, body: ScheduleIdPayload(scheduleId: scheduleId))
    }

    func executeAllTransferSchedules() async throws -> TransferExecutionResponse {
        try await request(endpoint: "/execute-all-transfer-schedules", method: .post, body: EmptyPayload())
    }

    func deleteTransferSchedule(scheduleId: Int) async throws -> MessageResponse {
        try await request(endpoint: "/delete-transfer-schedule", method: .delete, body: ScheduleIdPayload(scheduleId: scheduleId))
    }

    func getIncomeSchedules() async throws -> [IncomeSchedule] {
        try await request(endpoint: "/income-schedules")
    }

    func addIncomeSchedule(schedule: IncomeScheduleSubmission) async throws -> IncomeSchedule {
        try await request(endpoint: "/add-income-schedule", method: .post, body: schedule)
    }

    func executeIncomeSchedule(scheduleId: Int) async throws -> MessageResponse {
        try await request(endpoint: "/execute-income-schedule", method: .post, body: ScheduleIdPayload(scheduleId: scheduleId))
    }

    func executeAllIncomeSchedules() async throws -> IncomeExecutionResponse {
        try await request(endpoint: "/execute-all-income-schedules", method: .post, body: EmptyPayload())
    }

    func deleteIncomeSchedule(scheduleId: Int) async throws -> MessageResponse {
        try await request(endpoint: "/delete-income-schedule", method: .delete, body: ScheduleIdPayload(scheduleId: scheduleId))
    }

    func getAvailableTransfers() async throws -> AvailableTransfers {
        try await request(endpoint: "/get-available-transfers")
    }

    // MARK: - Base URL Configuration

    func updateBaseURL(_ newURL: String) {
        var urlToSave = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlToSave.hasSuffix("/") {
            urlToSave += "/"
        }
        UserDefaults.standard.set(urlToSave, forKey: Self.baseURLKey)
        UserDefaults.standard.synchronize()
    }

    func loadSavedURL() -> String {
        UserDefaults.standard.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL
    }

    // MARK: - Private Helpers

    private static let baseURLKey = "api_base_url"
    private static let defaultBaseURL = "http://localhost:3000/"

    private func resolveURL(for endpoint: String) throws -> URL {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: loadSavedURL()) else {
            throw APIServiceError.invalidBaseURL(loadSavedURL())
        }

        let normalizedEndpoint = trimmedEndpoint.hasPrefix("/") ? String(trimmedEndpoint.dropFirst()) : trimmedEndpoint
        return base.appendingPathComponent(normalizedEndpoint)
    }

    private func request<T: Decodable, Body: Encodable>(endpoint: String, method: HTTPMethod = .get, body: Body) async throws -> T {
        try await performRequest(endpoint: endpoint, method: method, body: body)
    }

    private func request<T: Decodable>(endpoint: String, method: HTTPMethod = .get) async throws -> T {
        try await performRequest(endpoint: endpoint, method: method, body: Optional<EmptyPayload>.none)
    }

    private func performRequest<T: Decodable, Body: Encodable>(endpoint: String, method: HTTPMethod, body: Body?) async throws -> T {
        let url = try resolveURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIServiceError.unknown(error)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let serverMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let message = serverMessage?["error"] as? String ?? serverMessage?["message"] as? String
                throw APIServiceError.server(code: httpResponse.statusCode, message: message)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                throw APIServiceError.decoding(decodingError)
            } catch {
                throw APIServiceError.unknown(error)
            }
        } catch let urlError as URLError {
            throw APIServiceError.transport(urlError)
        } catch {
            if let apiError = error as? APIServiceError {
                throw apiError
            }
            throw APIServiceError.unknown(error)
        }
    }

    // MARK: - Request Payload Types

    private struct EmptyPayload: Encodable {}

    private struct UpdateAccountPayload: Encodable {
        let accountId: Int
        let updatedAccount: AccountSubmission
    }

    private struct AccountIdPayload: Encodable {
        let accountId: Int
    }

    private struct CardOrderPayload: Encodable {
        let cardIds: [Int]
    }

    private struct AddPotPayload: Encodable {
        let accountId: Int
        let pot: PotSubmission
    }

    private struct UpdatePotPayload: Encodable {
        let originalAccountId: Int
        let originalPot: Pot
        let updatedPot: PotSubmission
    }

    private struct DeletePotPayload: Encodable {
        let accountName: String
        let potName: String
    }

    private struct TogglePotExclusionPayload: Encodable {
        let accountId: Int
        let potName: String
    }

    private struct AddExpensePayload: Encodable {
        let accountId: Int
        let expense: ExpenseSubmission
    }

    private struct AddIncomePayload: Encodable {
        let accountId: Int
        let income: IncomeSubmission
    }

    private struct DeleteExpensePayload: Encodable {
        let accountId: Int
        let expenseId: Int
    }

    private struct DeleteIncomePayload: Encodable {
        let accountId: Int
        let incomeId: Int
    }

    private struct AddScheduledPaymentPayload: Encodable {
        let accountId: Int
        let payment: ScheduledPaymentSubmission
    }

    private struct DeleteScheduledPaymentPayload: Encodable {
        let accountId: Int
        let paymentName: String
        let paymentDate: String
        let potName: String?
    }

    private struct ScheduleIdPayload: Encodable {
        let scheduleId: Int
    }
}
