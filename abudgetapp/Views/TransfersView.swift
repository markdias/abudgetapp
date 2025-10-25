import SwiftUI

struct TransfersView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        LargeActionButton(title: "Manage Transfer Schedules", color: .blue) { }
                        LargeActionButton(title: "Manage Income Schedules", color: .green) { }
                        LargeActionButton(title: "Salary Sorter", color: .purple) { }
                        LargeActionButton(title: "Reset Balance", color: .red) { }
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Transfers")
        }
    }
}

private struct LargeActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .foregroundStyle(.white)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: color.opacity(0.18), radius: 8, x: 0, y: 4)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    TransfersView()
}
