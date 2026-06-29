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
    @State private var animatingIDs: Set<UUID> = []
    @State private var pinScale: Double = 1.0
    @State private var cameraDistance: CLLocationDistance = 5000
    @State private var isRefreshing = false

    private var clusters: [SightingCluster] {
        SightingCluster.compute(from: supabase.sightings, distance: cameraDistance)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            bottomLayer
        }
        .sheet(isPresented: $showAddCat) { AddCatView() }
        .sheet(item: $detailSighting) { CatDetailView(sighting: $0) }
        .onChange(of: supabase.sightings, handleSightingsChange)
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            ForEach(clusters) { cluster in
                Annotation("", coordinate: cluster.center) {
                    if cluster.isCluster {
                        ClusterPinView(count: cluster.sightings.count, scale: pinScale)
                            .onTapGesture { zoomIntoCluster(cluster) }
                    } else {
                        let sighting = cluster.sightings[0]
                        CatPinView(sighting: sighting, isAnimating: animatingIDs.contains(sighting.id), scale: pinScale)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) { previewSighting = sighting }
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
            pinScale = pinScaleFactor(for: context.camera.distance)
            cameraDistance = context.camera.distance
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { catCountBadge }
        .overlay(alignment: .topTrailing) { refreshButton }
    }

    // MARK: - Bottom overlay

    @ViewBuilder
    private var bottomLayer: some View {
        if let sighting = previewSighting {
            CatPreviewCard(
                sighting: sighting,
                onDetail: { detailSighting = sighting },
                onDismiss: { withAnimation(.spring(response: 0.3)) { previewSighting = nil } }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 24)
        } else {
            addButton
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var catCountBadge: some View {
        if !supabase.sightings.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill").font(.caption2)
                Text("\(supabase.sightings.count)마리")
                    .font(.caption.bold())
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            .padding(.top, 56)
        }
    }

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
                .animation(
                    isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default,
                    value: isRefreshing
                )
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

    private func pinScaleFactor(for distance: CLLocationDistance) -> Double {
        let minDist = 300.0, maxDist = 500_000.0
        let clamped = max(minDist, min(maxDist, distance))
        let t = (log10(clamped) - log10(minDist)) / (log10(maxDist) - log10(minDist))
        return 1.6 - t * 1.25
    }

    private func zoomIntoCluster(_ cluster: SightingCluster) {
        withAnimation {
            cameraPosition = .camera(MapCamera(centerCoordinate: cluster.center, distance: max(300, cameraDistance / 5)))
        }
    }

    private func handleSightingsChange(old: [CatSighting], new: [CatSighting]) {
        if let preview = previewSighting, !new.contains(where: { $0.id == preview.id }) {
            withAnimation(.spring(response: 0.3)) { previewSighting = nil; detailSighting = nil }
        }

        let newIDs = Set(new.map(\.id)).subtracting(Set(old.map(\.id)))
        guard !newIDs.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { animatingIDs.formUnion(newIDs) }
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            animatingIDs.subtract(newIDs)
        }
    }
}
