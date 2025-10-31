import Foundation

class ExecutionLogsManager {
    private static let logsKey = "executionLogs"
    private static let decoder = JSONDecoder()
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    // MARK: - Add Log
    static func addLog(_ processName: String, itemCount: Int, wasAutomatic: Bool) {
        let log = ExecutionLog(processName: processName, itemCount: itemCount, wasAutomatic: wasAutomatic)
        var logs = getLogs()
        logs.insert(log, at: 0) // Add to front (most recent first)

        // Keep only last 100 logs
        logs = Array(logs.prefix(100))
        saveLogs(logs)
    }

    // MARK: - Get Logs
    static func getLogs() -> [ExecutionLog] {
        guard let data = UserDefaults.standard.data(forKey: logsKey),
              let logs = try? decoder.decode([ExecutionLog].self, from: data) else {
            return []
        }
        return logs
    }

    static func getLogsForProcess(_ processName: String) -> [ExecutionLog] {
        getLogs().filter { $0.processName == processName }
    }

    // MARK: - Clear Logs
    static func clearAllLogs() {
        UserDefaults.standard.removeObject(forKey: logsKey)
    }

    static func clearLogsForProcess(_ processName: String) {
        let logs = getLogs().filter { $0.processName != processName }
        saveLogs(logs)
    }

    // MARK: - Private Helper
    private static func saveLogs(_ logs: [ExecutionLog]) {
        if let encoded = try? encoder.encode(logs) {
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
    }
}
