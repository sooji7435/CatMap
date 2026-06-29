//
//  ContentView.swift
//  CatMap
//
//  Created by 박윤수 on 6/29/26.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(SupabaseService.self) private var supabase
    @Environment(LocationManager.self) private var locationManager
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showAddCat = false
    @State private var selectedSighting: CatSighting?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(supabase.sightings) { sighting in
                    Annotation("", coordinate: sighting.coordinate) {
                        CatPinView(sighting: sighting)
                            .onTapGesture { selectedSighting = sighting }
                    }
                }
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            Button {
                showAddCat = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.orange)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            }
            .padding(24)
        }
        .sheet(isPresented: $showAddCat) {
            AddCatView()
        }
        .sheet(item: $selectedSighting) { sighting in
            CatDetailView(sighting: sighting)
        }
        .onAppear {
            locationManager.requestPermission()
            supabase.startListening()
        }
        .onDisappear {
            supabase.stopListening()
        }
    }
}

struct CatPinView: View {
    let sighting: CatSighting

    var body: some View {
        if let urlString = sighting.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                default:
                    catEmoji
                }
            }
        } else {
            catEmoji
        }
    }

    private var catEmoji: some View {
        ZStack {
            Circle()
                .fill(.orange)
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Text("🐱")
                .font(.title3)
        }
    }
}
