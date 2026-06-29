//
//  ContentView.swift
//  CatMap
//
//  Created by 박윤수 on 6/29/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @Environment(SupabaseService.self) private var supabase
    @Environment(LocationManager.self) private var locationManager
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showAddCat = false
    @State private var previewSighting: CatSighting?
    @State private var detailSighting: CatSighting?
    @State private var filterKm: Double? = nil
    @State private var animatingIDs: Set<UUID> = []

    private var filteredSightings: [CatSighting] {
        guard let km = filterKm, let location = locationManager.location else {
            return supabase.sightings
        }
        return supabase.sightings.filter { sighting in
            let loc = CLLocation(latitude: sighting.latitude, longitude: sighting.longitude)
            return location.distance(from: loc) <= km * 1000
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                ForEach(filteredSightings) { sighting in
                    Annotation("", coordinate: sighting.coordinate) {
                        CatPinView(
                            sighting: sighting,
                            isAnimating: animatingIDs.contains(sighting.id)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                previewSighting = sighting
                            }
                        }
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
            .overlay(alignment: .top) { filterBar }

            if let sighting = previewSighting {
                CatPreviewCard(
                    sighting: sighting,
                    onDetail: { detailSighting = sighting },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3)) {
                            previewSighting = nil
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 24)
            } else {
                addButton
            }
        }
        .sheet(isPresented: $showAddCat) {
            AddCatView()
        }
        .sheet(item: $detailSighting) { sighting in
            CatDetailView(sighting: sighting)
        }
        .onAppear {
            locationManager.requestPermission()
            supabase.startListening()
        }
        .onDisappear {
            supabase.stopListening()
        }
        .onChange(of: supabase.sightings) { old, new in
            // 삭제된 항목이면 미리보기 카드 닫기
            if let preview = previewSighting, !new.contains(where: { $0.id == preview.id }) {
                withAnimation(.spring(response: 0.3)) {
                    previewSighting = nil
                    detailSighting = nil
                }
            }

            // 새 핀 등장 애니메이션
            let newIDs = Set(new.map(\.id)).subtracting(Set(old.map(\.id)))
            guard !newIDs.isEmpty else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                animatingIDs = animatingIDs.union(newIDs)
            }
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                animatingIDs = animatingIDs.subtracting(newIDs)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "전체", isSelected: filterKm == nil) { filterKm = nil }
                FilterChip(title: "500m", isSelected: filterKm == 0.5) { filterKm = 0.5 }
                FilterChip(title: "1km", isSelected: filterKm == 1.0) { filterKm = 1.0 }
                FilterChip(title: "5km", isSelected: filterKm == 5.0) { filterKm = 5.0 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private var addButton: some View {
        HStack {
            Spacer()
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
    }
}

struct CatPinView: View {
    let sighting: CatSighting
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 2) {
            if let name = sighting.name, !name.isEmpty {
                Text(name)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }
            pinContent
        }
        .scaleEffect(isAnimating ? 1.35 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isAnimating)
    }

    @ViewBuilder
    private var pinContent: some View {
        if let url = sighting.firstPhotoURL {
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

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.orange : Color(.systemBackground))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        }
    }
}
