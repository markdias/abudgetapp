import Foundation
import Combine

class APIService {
    static let shared = APIService()
    
    private var baseURL: String {
        return loadSavedURL()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Account Methods
    func getAccounts() -> AnyPublisher<[Account], Error> {
        print("[APIService] Requesting accounts from \(baseURL)/accounts")
        return requestGet(endpoint: "/accounts")
    }
    
    func getSavingsInvestments() -> AnyPublisher<[Account], Error> {
        return requestGet(endpoint: "/savings-investments")
    }
    
    func addAccount(account: AccountSubmission) -> AnyPublisher<Account, Error> {
        return requestPost(endpoint: "/add-account", encodable: account)
    }
    
    func updateAccount(accountId: Int, updatedAccount: AccountSubmission) -> AnyPublisher<Account, Error> {
        let payload = UpdateAccountPayload(accountId: accountId, updatedAccount: updatedAccount)
        return requestPost(endpoint: "/update-account", method: "PUT", encodable: payload)
    }
    
    func deleteAccount(accountId: Int) -> AnyPublisher<MessageResponse, Error> {
        let payload = DeleteAccountPayload(accountId: accountId)
        return requestPost(endpoint: "/delete-account", method: "DELETE", encodable: payload)
    }
    
    // MARK: - Pot Methods
    func addPot(accountId: Int, pot: PotSubmission) -> AnyPublisher<Pot, Error> {
        let payload = AddPotPayload(accountId: accountId, pot: pot)
        return requestPost(endpoint: "/add-pot", encodable: payload)
    }
    
    func updatePot(originalAccountId: Int, originalPot: Pot, updatedPot: PotSubmission) -> AnyPublisher<Pot, Error> {
        let payload = UpdatePotPayload(
            originalAccountId: originalAccountId,
            originalPot: originalPot,
            updatedPot: updatedPot
        )
        return requestPost(endpoint: "/update-pot", method: "PUT", encodable: payload)
    }
    
    func deletePot(accountName: String, potName: String) -> AnyPublisher<MessageResponse, Error> {
        let payload = DeletePotPayload(accountName: accountName, potName: potName)
        return requestPost(endpoint: "/delete-pot", method: "DELETE", encodable: payload)
    }
    
    // MARK: - Transaction Methods
    func addExpense(accountId: Int, expense: ExpenseSubmission) -> AnyPublisher<Expense, Error> {
        let payload = AddExpensePayload(accountId: accountId, expense: expense)
        return requestPost(endpoint: "/add-expense", encodable: payload)
    }
    
    func addIncome(accountId: Int, income: IncomeSubmission) -> AnyPublisher<Income, Error> {
        let payload = AddIncomePayload(accountId: accountId, income: income)
        return requestPost(endpoint: "/add-income", encodable: payload)
    }
    
    func deleteExpense(accountId: Int, expenseId: Int) -> AnyPublisher<MessageResponse, Error> {
        let payload = DeleteExpensePayload(accountId: accountId, expenseId: expenseId)
        return requestPost(endpoint: "/delete-expense", method: "DELETE", encodable: payload)
    }
    
    func deleteIncome(accountId: Int, incomeId: Int) -> AnyPublisher<MessageResponse, Error> {
        let payload = DeleteIncomePayload(accountId: accountId, incomeId: incomeId)
        return requestPost(endpoint: "/delete-income", method: "DELETE", encodable: payload)
    }
    
    // MARK: - Scheduled Payments Methods
    func addScheduledPayment(accountId: Int, payment: ScheduledPaymentSubmission) -> AnyPublisher<ScheduledPayment, Error> {
        let payload = AddScheduledPaymentPayload(accountId: accountId, payment: payment)
        return requestPost(endpoint: "/add-scheduled-payment", encodable: payload)
    }
    
    func deleteScheduledPayment(accountId: Int, paymentName: String, paymentDate: String, potName: String? = nil) -> AnyPublisher<MessageResponse, Error> {
        var payload = DeleteScheduledPaymentPayload(
            accountId: accountId,
            paymentName: paymentName,
            paymentDate: paymentDate
        )
        payload.potName = potName
        return requestPost(endpoint: "/delete-scheduled-payment", method: "DELETE", encodable: payload)
    }
    
    // MARK: - Budget Management Methods
    func resetBalances() -> AnyPublisher<ResetResponse, Error> {
        return requestPost(endpoint: "/reset-balances", encodable: EmptyPayload())
    }
    
    func toggleAccountExclusion(accountId: Int) -> AnyPublisher<ExclusionResponse, Error> {
        let payload = AccountIdPayload(accountId: accountId)
        return requestPost(endpoint: "/toggle-account-exclusion", encodable: payload)
    }
    
    func togglePotExclusion(accountId: Int, potName: String) -> AnyPublisher<ExclusionResponse, Error> {
        let payload = TogglePotExclusionPayload(accountId: accountId, potName: potName)
        return requestPost(endpoint: "/toggle-pot-exclusion", encodable: payload)
    }
    
    // MARK: - Transfer Methods
    func addTransferSchedule(transfer: TransferScheduleSubmission) async throws -> TransferSchedule {
        return try await withCheckedThrowingContinuation { continuation in
            requestPost(endpoint: "/add-transfer-schedule", encodable: transfer)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { schedule in
                        continuation.resume(returning: schedule)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    func executeTransferSchedule(scheduleId: Int) -> AnyPublisher<TransferExecutionResponse, Error> {
        let payload = ScheduleIdPayload(scheduleId: scheduleId)
        return requestPost(endpoint: "/execute-transfer-schedule", encodable: payload)
    }
    
    func executeAllTransferSchedules() -> AnyPublisher<TransferExecutionResponse, Error> {
        return requestPost(endpoint: "/execute-all-transfer-schedules", encodable: EmptyPayload())
    }
    
    func getTransferSchedules() -> AnyPublisher<[TransferSchedule], Error> {
        return requestGet(endpoint: "/transfer-schedules")
    }
    
    // MARK: - Income Schedule Methods
    func getIncomeSchedules() -> AnyPublisher<[IncomeSchedule], Error> {
        return requestGet(endpoint: "/income-schedules")
    }
    
    func addIncomeSchedule(schedule: IncomeScheduleSubmission) -> AnyPublisher<IncomeSchedule, Error> {
        return requestPost(endpoint: "/add-income-schedule", encodable: schedule)
    }
    
    func executeIncomeSchedule(scheduleId: Int) -> AnyPublisher<MessageResponse, Error> {
        let payload = ScheduleIdPayload(scheduleId: scheduleId)
        return requestPost(endpoint: "/execute-income-schedule", encodable: payload)
    }
    
    func executeAllIncomeSchedules() -> AnyPublisher<IncomeExecutionResponse, Error> {
        return requestPost(endpoint: "/execute-all-income-schedules", encodable: EmptyPayload())
    }
    
    // MARK: - Basic Request Methods
    
    // Method for GET requests
    private func requestGet<T: Decodable>(endpoint: String) -> AnyPublisher<T, Error> {
        return performRequest(endpoint: endpoint, method: "GET")
    }
    
    // Method for POST/PUT/DELETE requests with encodable body
    private func requestPost<T: Decodable, E: Encodable>(
        endpoint: String, 
        method: String = "POST", 
        encodable: E
    ) -> AnyPublisher<T, Error> {
        return performRequest(endpoint: endpoint, method: method, body: encodable)
    }
    
    // Implementation of the request
    private func performRequest<T: Decodable>(
        endpoint: String, 
        method: String, 
        body: Encodable? = nil
    ) -> AnyPublisher<T, Error> {
        guard let base = URL(string: baseURL) else {
            print("[APIService] Invalid base URL: \(baseURL)")
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        let trimmedEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = base.appendingPathComponent(trimmedEndpoint)
        print("[APIService] Making \(method) request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add body if it exists
        if let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(body)
            } catch {
                print("[APIService] Error encoding request body: \(error)")
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[APIService] Invalid response type")
                    throw URLError(.badServerResponse)
                }
                
                print("[APIService] Response status code: \(httpResponse.statusCode)")
                
                if !(200...299).contains(httpResponse.statusCode) {
                    // Try to extract error message from response
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        print("[APIService] Error from server: \(errorMessage)")
                        throw NSError(domain: "APIError", 
                                    code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    } else {
                        throw URLError(.badServerResponse)
                    }
                }
                
                // Print the first 200 chars of the response for debugging
                if let dataString = String(data: data, encoding: .utf8) {
                    let previewLength = min(dataString.count, 200)
                    let index = dataString.index(dataString.startIndex, offsetBy: previewLength)
                    let preview = dataString[..<index]
                    print("[APIService] Response preview: \(preview)...")
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    print("[APIService] Decoding error: \(decodingError)")
                    
                    // Special handling for decoding errors to provide clearer information
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("[APIService] Type mismatch: expected \(type) at path: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("[APIService] Value not found: expected \(type) at path: \(context.codingPath)")
                    case .keyNotFound(let key, let context):
                        print("[APIService] Key not found: \(key.stringValue) at path: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("[APIService] Data corrupted: \(context)")
                    @unknown default:
                        print("[APIService] Unknown decoding error: \(decodingError)")
                    }
                }
                return error
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // Method to update the base URL (useful for settings)
    func updateBaseURL(_ newURL: String) {
        // Ensure URL ends with slash if needed
        var urlToSave = newURL
        if !urlToSave.hasSuffix("/") {
            // Only add trailing slash if it's a base URL without path components
            if URL(string: urlToSave)?.path == "" || URL(string: urlToSave)?.path == "/" {
                urlToSave += "/"
            }
        }
        
        print("[APIService] Updating API base URL to: \(urlToSave)")
        
        // Only update if valid URL
        if URL(string: urlToSave) != nil {
            UserDefaults.standard.set(urlToSave, forKey: "api_base_url")
            UserDefaults.standard.synchronize()
        }
    }
    
    // Load saved URL from UserDefaults
    func loadSavedURL() -> String {
        let url = UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:3000"
        print("[APIService] Using API base URL: \(url)")
        return url
    }
    
    // MARK: - Request Payload Structs
    struct EmptyPayload: Codable {}
    
    struct UpdateAccountPayload: Codable {
        let accountId: Int
        let updatedAccount: AccountSubmission
    }
    
    struct DeleteAccountPayload: Codable {
        let accountId: Int
    }
    
    struct AccountIdPayload: Codable {
        let accountId: Int
    }
    
    struct AddPotPayload: Codable {
        let accountId: Int
        let pot: PotSubmission
    }
    
    struct UpdatePotPayload: Codable {
        let originalAccountId: Int
        let originalPot: Pot
        let updatedPot: PotSubmission
    }
    
    struct DeletePotPayload: Codable {
        let accountName: String
        let potName: String
    }
    
    struct TogglePotExclusionPayload: Codable {
        let accountId: Int
        let potName: String
    }
    
    struct AddExpensePayload: Codable {
        let accountId: Int
        let expense: ExpenseSubmission
    }
    
    struct AddIncomePayload: Codable {
        let accountId: Int
        let income: IncomeSubmission
    }
    
    struct DeleteExpensePayload: Codable {
        let accountId: Int
        let expenseId: Int
    }
    
    struct DeleteIncomePayload: Codable {
        let accountId: Int
        let incomeId: Int
    }
    
    struct AddScheduledPaymentPayload: Codable {
        let accountId: Int
        let payment: ScheduledPaymentSubmission
    }
    
    struct DeleteScheduledPaymentPayload: Codable {
        let accountId: Int
        let paymentName: String
        let paymentDate: String
        var potName: String? = nil
    }
    
    struct ScheduleIdPayload: Codable {
        let scheduleId: Int
    }
}