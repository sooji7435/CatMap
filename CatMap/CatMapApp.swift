import SwiftUI

@main
struct CatMapApp: App {
    @State private var supabase = SupabaseService()
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("지도", systemImage: "map.fill") }
                MyRecordsView()
                    .tabItem { Label("내 기록", systemImage: "pawprint.fill") }
            }
            .tint(.orange)
            .environment(supabase)
            .environment(locationManager)
            .onAppear {
                locationManager.requestPermission()
                supabase.startListening()
            }
            .onDisappear { supabase.stopListening() }
        }
    }
}
