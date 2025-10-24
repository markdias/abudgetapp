//
//  TransactionsView.swift
//  abudgetapp
//

import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var accountsStore: AccountsStore
    @EnvironmentObject private var scheduledPaymentsStore: ScheduledPaymentsStore
    @State private var searchText = ""
    @State private var selectedFilter: ActivityStore.Filter = .all
    @State private var selectedActivity: ActivityItem?

    private var filteredActivities: [ActivityItem] {
        var activities = activityStore.activities
        if let category = selectedFilter.category {
            activities = activities.filter { $0.category == category }
        }
        if searchText.isEmpty { return activities }
        return activities.filter { activity in
            activity.title.localizedCaseInsensitiveContains(searchText) ||
            activity.accountName.localizedCaseInsensitiveContains(searchText) ||
            (activity.potName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredActivities) { activity in
                    ActivityRow(activity: activity, isMarked: activityStore.markedIdentifiers.contains(activity.id))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedActivity = activity
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await deleteActivity(activity) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                selectedActivity = activity
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }.tint(.blue)
                        }
                }
            }
            .overlay {
                if filteredActivities.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "tray",
                        description: Text("Adjust the filters or search to see activity items.")
                    )
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ActivityStore.Filter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .searchable(text: $searchText, prompt: "Search activity")
            .sheet(item: $selectedActivity) { ActivityEditorSheet(activity: $0) }
        }
    }

    private func deleteActivity(_ activity: ActivityItem) async {
        guard let accountId = accountsStore.accounts.first(where: { $0.name == activity.accountName })?.id else { return }
        let parts = activity.id.split(separator: "-")
        let numericId = Int(parts.last ?? "")
        switch activity.category {
        case .income:
            if let id = numericId { await accountsStore.deleteIncome(accountId: accountId, incomeId: id) }
        case .expense:
            if let id = numericId { await accountsStore.deleteExpense(accountId: accountId, expenseId: id) }
        case .scheduledPayment:
            if let id = numericId, let context = scheduledPaymentsStore.items.first(where: { $0.accountId == accountId && $0.payment.id == id }) {
                await scheduledPaymentsStore.deletePayment(context: context)
            }
        case .transaction:
            if let transactionIdString = activity.metadata["transactionId"], let transactionId = Int(transactionIdString) {
                await accountsStore.deleteTransaction(id: transactionId)
            }
        }
    }
}

#Preview {
    let accountsStore = AccountsStore()
    let activityStore = ActivityStore(accountsStore: accountsStore)
    let scheduledStore = ScheduledPaymentsStore(accountsStore: accountsStore)
    return TransactionsView()
        .environmentObject(activityStore)
        .environmentObject(accountsStore)
        .environmentObject(scheduledStore)
}
