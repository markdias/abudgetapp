import SwiftUI

struct ExecutionLogsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var executionLogs: [ExecutionLog] = []
    @State private var expandedSections: Set<String> = []
    @State private var expandedLogItems: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if executionLogs.isEmpty {
                            emptyState
                        } else {
                            allLogsSection
                            logsSections
                        }

                        Divider()
                            .padding(.vertical, 16)

                        HStack(spacing: 12) {
                            Button(action: {
                                ExecutionLogsManager.clearAllLogs()
                                executionLogs = []
                            }) {
                                Label("Clear All Logs", systemImage: "trash")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                            .disabled(executionLogs.isEmpty)
                            .opacity(executionLogs.isEmpty ? 0.5 : 1.0)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Execution Logs")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .onAppear {
                executionLogs = ExecutionLogsManager.getLogs()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Execution Logs")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Execution logs will appear here when processes are run manually or automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var allLogsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { toggleSection("all") }) {
                HStack(spacing: 12) {
                    Image(systemName: expandedSections.contains("all") ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ModernTheme.primaryAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Logs")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("\(executionLogs.count) \(executionLogs.count == 1 ? "execution" : "executions")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(executionLogs.count > 0 ? "Latest: " + dateFormatter(executionLogs[0].executedAt) : "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            if expandedSections.contains("all") {
                Divider()
                    .padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(executionLogs, id: \.id) { log in
                        allLogsEntryRow(log: log)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                )
        )
        .padding(.horizontal, 20)
    }

    private var logsSections: some View {
        VStack(spacing: 12) {
            ForEach(groupedLogs.keys.sorted(), id: \.self) { processName in
                processSection(name: processName, logs: groupedLogs[processName] ?? [])
            }
        }
        .padding(.horizontal, 20)
    }

    private func processSection(name: String, logs: [ExecutionLog]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { toggleSection(name) }) {
                HStack(spacing: 12) {
                    Image(systemName: expandedSections.contains(name) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ModernTheme.primaryAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("\(logs.count) \(logs.count == 1 ? "execution" : "executions")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(logs.count > 0 ? "Latest: " + dateFormatter(logs[0].executedAt) : "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            if expandedSections.contains(name) {
                Divider()
                    .padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(logs, id: \.id) { log in
                        logEntryRow(log: log)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: ModernTheme.elementCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.14), lineWidth: 0.8)
                )
        )
    }

    private func logEntryRow(log: ExecutionLog) -> some View {
        let isExpanded = expandedLogItems.contains(log.id)

        return VStack(alignment: .leading, spacing: 6) {
            Button(action: { toggleLogItem(log.id) }) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(dateFormatter(log.executedAt))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            if log.wasAutomatic {
                                Label("Auto", systemImage: "bolt.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Label("Manual", systemImage: "hand.tap.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        HStack(spacing: 8) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ModernTheme.primaryAccent)
                            Text("Processed \(log.itemCount) \(log.itemCount == 1 ? "item" : "items")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.3))
                .cornerRadius(8)
            }

            if isExpanded, let itemNames = log.itemNames, !itemNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(itemNames, id: \.self) { itemName in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(ModernTheme.primaryAccent.opacity(0.4))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)

                            Text(itemName)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2))
                .cornerRadius(8)
            }
        }
    }

    private func allLogsEntryRow(log: ExecutionLog) -> some View {
        let isExpanded = expandedLogItems.contains(log.id)

        return VStack(alignment: .leading, spacing: 6) {
            Button(action: { toggleLogItem(log.id) }) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ModernTheme.primaryAccent)
                            Text(log.processName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(ModernTheme.primaryAccent)
                        }
                        HStack(spacing: 8) {
                            Text(dateFormatter(log.executedAt))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                            if log.wasAutomatic {
                                Label("Auto", systemImage: "bolt.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Label("Manual", systemImage: "hand.tap.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(log.itemCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(log.itemCount == 1 ? "item" : "items")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.3))
                .cornerRadius(8)
            }

            if isExpanded, let itemNames = log.itemNames, !itemNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(itemNames, id: \.self) { itemName in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(ModernTheme.primaryAccent.opacity(0.4))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)

                            Text(itemName)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2))
                .cornerRadius(8)
            }
        }
    }

    private var groupedLogs: [String: [ExecutionLog]] {
        Dictionary(grouping: executionLogs, by: { $0.processName })
            .mapValues { logs in logs.sorted { $0.executedAt > $1.executedAt } }
    }

    private func toggleSection(_ name: String) {
        if expandedSections.contains(name) {
            expandedSections.remove(name)
        } else {
            expandedSections.insert(name)
        }
    }

    private func toggleLogItem(_ id: UUID) {
        if expandedLogItems.contains(id) {
            expandedLogItems.remove(id)
        } else {
            expandedLogItems.insert(id)
        }
    }

    private func dateFormatter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy · h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    ExecutionLogsView()
}
