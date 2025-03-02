import SwiftUI
import Combine

@main
struct AbudgetApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .accentColor(.purple)
                .onAppear {
                    APIService.shared.updateBaseURL("http://localhost:3000")
                    appState.fetchData()
                }
        }
    }
} 