import SwiftUI
import MapKit
import CoreLocation

// MARK: - Cluster model

private struct SightingCluster: Identifiable {
    let sightings: [CatSighting]
    var id: String { sightings.map { $0.id.uuidString }.sorted().joined() }
    var center: CLLocationCoordinate2D {
        let lat = sightings.map(\.latitude).reduce(0, +) / Double(sightings.count)
        let lon = sightings.map(\.longitude).reduce(0, +) / Double(sightings.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    var isCluster: Bool { sightings.count > 1 }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(SupabaseService.self) private var supabase
    @Environment(LocationManager.self) private var locationManager
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showAddCat = false
    @State private var previewSighting: CatSighting?
    @State private var detailSighting: CatSighting?
    @State private var animatingIDs: Set<UUID> = []
    @State private var pinScale: Double = 1.0
    @State private var cameraDistance: CLLocationDistance = 5000
    @State private var isRefreshing = false

    private var clusters: [SightingCluster] {
        computeClusters(supabase.sightings, distance: cameraDistance)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                ForEach(clusters) { cluster in
                    Annotation("", coordinate: cluster.center) {
                        if cluster.isCluster {
                            ClusterPinView(count: cluster.sightings.count, scale: pinScale)
                                .onTapGesture { zoomIntoCluster(cluster) }
                        } else {
                            let sighting = cluster.sightings[0]
                            CatPinView(
                                sighting: sighting,
                                isAnimating: animatingIDs.contains(sighting.id),
                                scale: pinScale
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    previewSighting = sighting
                                }
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
            .onMapCameraChange(frequency: .continuous) { context in
                pinScale = scaleFactor(for: context.camera.distance)
                cameraDistance = context.camera.distance
            }
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) { refreshButton }

            if let sighting = previewSighting {
                CatPreviewCard(
                    sighting: sighting,
                    onDetail: { detailSighting = sighting },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3)) { previewSighting = nil }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 24)
            } else {
                addButton
            }
        }
        .sheet(isPresented: $showAddCat) { AddCatView() }
        .sheet(item: $detailSighting) { CatDetailView(sighting: $0) }
        .onAppear {
            locationManager.requestPermission()
            supabase.startListening()
        }
        .onDisappear { supabase.stopListening() }
        .onChange(of: supabase.sightings) { old, new in
            if let preview = previewSighting, !new.contains(where: { $0.id == preview.id }) {
                withAnimation(.spring(response: 0.3)) {
                    previewSighting = nil
                    detailSighting = nil
                }
            }

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

    // MARK: - Subviews

    private var refreshButton: some View {
        Button {
            guard !isRefreshing else { return }
            isRefreshing = true
            Task {
                await supabase.refresh()
                try? await Task.sleep(for: .seconds(0.4))
                isRefreshing = false
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                .frame(width: 36, height: 36)
                .background(.thinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        }
        .padding(.top, 56)
        .padding(.trailing, 12)
    }

    private var addButton: some View {
        HStack {
            Spacer()
            Button { showAddCat = true } label: {
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

    // MARK: - Helpers

    private func scaleFactor(for distance: CLLocationDistance) -> Double {
        let minDist = 300.0
        let maxDist = 500_000.0
        let clamped = max(minDist, min(maxDist, distance))
        let t = (log10(clamped) - log10(minDist)) / (log10(maxDist) - log10(minDist))
        return 1.6 - t * 1.25
    }

    private func computeClusters(_ sightings: [CatSighting], distance: CLLocationDistance) -> [SightingCluster] {
        guard !sightings.isEmpty else { return [] }
        let threshold = distance / 3_000_000.0
        var remaining = sightings
        var result: [SightingCluster] = []

        while !remaining.isEmpty {
            let seed = remaining.removeFirst()
            var group = [seed]
            var rest: [CatSighting] = []
            for s in remaining {
                if abs(s.latitude - seed.latitude) < threshold && abs(s.longitude - seed.longitude) < threshold {
                    group.append(s)
                } else {
                    rest.append(s)
                }
            }
            remaining = rest
            result.append(SightingCluster(sightings: group))
        }
        return result
    }

    private func zoomIntoCluster(_ cluster: SightingCluster) {
        withAnimation {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: cluster.center,
                distance: max(300, cameraDistance / 5)
            ))
        }
    }
}

// MARK: - CatPinView

struct CatPinView: View {
    let sighting: CatSighting
    let isAnimating: Bool
    let scale: Double

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
        .scaleEffect(scale * (isAnimating ? 1.35 : 1.0))
        .animation(.easeOut(duration: 0.15), value: scale)
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
                        .overlay(Circle().stroke(statusColor, lineWidth: 2.5))
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
            Text("🐱").font(.title3)
        }
    }

    private var statusColor: Color {
        switch sighting.catStatus {
        case .healthy: return .green
        case .injured: return .red
        case .kitten:  return .blue
        case nil:      return .white
        }
    }
}

// MARK: - ClusterPinView

struct ClusterPinView: View {
    let count: Int
    let scale: Double

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(.orange)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Text("🐱").font(.title3)
            }
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.red)
                .clipShape(Capsule())
                .offset(x: 6, y: -4)
        }
        .scaleEffect(scale)
        .animation(.easeOut(duration: 0.15), value: scale)
    }
}
