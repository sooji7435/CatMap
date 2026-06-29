//
//  CatMapApp.swift
//  CatMap
//
//  Created by 박윤수 on 6/29/26.
//

import SwiftUI

@main
struct CatMapApp: App {
    @State private var supabase = SupabaseService()
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(supabase)
                .environment(locationManager)
        }
    }
}
