//
//  TransactionsView.swift
//  abudgetapp
//

import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @State private var searchText = ""
    @State private var selectedFilter: ActivityStore.Filter = .all

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
                }
            }
            .overlay {
                if filteredActivities.isEmpty {
                    ContentUnavailableView("No Activity", systemImage: "tray") {
                        Text("Adjust the filters or search to see transactions.")
                    }
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
        }
    }
}

#Preview {
    TransactionsView()
        .environmentObject(ActivityStore(accountsStore: AccountsStore()))
}
