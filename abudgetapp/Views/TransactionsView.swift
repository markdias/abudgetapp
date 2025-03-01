//
//  TransactionsView.swift
//  abudgetapp
//

import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all
    
    var filteredTransactions: [Transaction] {
        // Use appState.transactions instead of local transactions property
        let searchResults = searchText.isEmpty ? appState.transactions : appState.transactions.filter { 
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
        
        switch selectedFilter {
        case .all:
            return searchResults
        case .income:
            return searchResults.filter { $0.isIncome }
        case .expense:
            return searchResults.filter { !$0.isIncome && !$0.isPayment }
        case .payments:
            return searchResults.filter { $0.isPayment }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter segment control
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(TransactionFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if filteredTransactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "tray",
                        description: Text("There are no transactions that match your search criteria.")
                    )
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Action to add a new transaction
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case income = "Income"
    case expense = "Expenses"
    case payments = "Payments"
}

#Preview {
    TransactionsView()
        .environmentObject(AppState())
}
