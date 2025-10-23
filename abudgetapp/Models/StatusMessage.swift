import Foundation

public struct StatusMessage: Identifiable, Equatable {
    public enum Kind {
        case success
        case info
        case warning
        case error
    }

    public let id = UUID()
    public let title: String
    public let message: String
    public let kind: Kind
    public let timestamp: Date

    public init(title: String, message: String, kind: Kind, timestamp: Date = Date()) {
        self.title = title
        self.message = message
        self.kind = kind
        self.timestamp = timestamp
    }
}
