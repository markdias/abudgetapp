import Foundation

struct ExecutionPurgeSummary: Sendable {
    let runTimestamps: [String]
    let transactionEventsRemoved: Int
    let incomeEventsRemoved: Int
    let processedLogsRemoved: Int
    let transactionsRemoved: Int
    let incomeSchedulesRemoved: Int

    var totalExecutionsRemoved: Int {
        transactionEventsRemoved + incomeEventsRemoved
    }

    var totalRunsAffected: Int {
        runTimestamps.count
    }
}
