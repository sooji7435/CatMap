import SwiftUI
import MapKit

struct CatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseService.self) private var supabase

    let sighting: CatSighting

    @State private var showDeleteAlert = false
    @State private var showAddPhotoSource = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isLiked = false
    @State private var likeCount = 0

    // 실시간 업데이트 반영
    private var live: CatSighting {
        supabase.sightings.first { $0.id == sighting.id } ?? sighting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    photoGallery
                    statusBadge
                    headerSection
                    infoSection
                    miniMapSection
                }
            }
            .navigationTitle("길냥이")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showAddPhotoSource = true
                        } label: {
                            Image(systemName: supabase.isUploading ? "arrow.triangle.2.circlepath" : "photo.badge.plus")
                                .foregroundStyle(.orange)
                        }
                        .disabled(supabase.isUploading)

                        if supabase.isOwner(live) {
                            Button {
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .alert("삭제할까요?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    Task { try? await supabase.deleteSighting(live); dismiss() }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 길냥이 기록이 삭제됩니다.")
            }
            .confirmationDialog("사진 선택", isPresented: $showAddPhotoSource) {
                Button("카메라로 찍기") { showCamera = true }
                Button("앨범에서 선택") { showGallery = true }
                Button("취소", role: .cancel) {}
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: addPhotoBinding, sourceType: .camera).ignoresSafeArea()
            }
            .sheet(isPresented: $showGallery) {
                ImagePicker(image: addPhotoBinding, sourceType: .photoLibrary).ignoresSafeArea()
            }
        }
        .onAppear {
            isLiked = supabase.isLiked(sighting)
            likeCount = sighting.likes
        }
        .onChange(of: live.likes) { _, newValue in
            likeCount = newValue
        }
    }

    // MARK: - Photo gallery with pinch zoom

    @ViewBuilder
    private var photoGallery: some View {
        if !live.photoURLs.isEmpty {
            TabView {
                ForEach(live.photoURLs, id: \.self) { urlString in
                    if let url = URL(string: urlString) {
                        ZoomableAsyncImage(url: url)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .tabViewStyle(.page)
            .frame(height: 300)
            .overlay(alignment: .bottomTrailing) {
                if live.photoURLs.count > 1 {
                    Text("\(live.photoURLs.count)장")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
        }
    }

    // MARK: - Status badge

    @ViewBuilder
    private var statusBadge: some View {
        if let s = live.catStatus {
            Label(s.label, systemImage: s.systemImage)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(s.color)
                .clipShape(Capsule())
                .padding(.horizontal)
                .padding(.top, 12)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let name = live.name, !name.isEmpty {
                    Text(name).font(.title2.bold())
                }
                Label(
                    live.locationName ?? String(format: "%.5f, %.5f", live.latitude, live.longitude),
                    systemImage: "location"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button { likeToggle() } label: {
                VStack(spacing: 2) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title2).foregroundStyle(.red)
                    Text("\(likeCount)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !live.note.isEmpty {
                Text(live.note).font(.body)
            }
            Divider()
            Label(live.date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Mini map

    private var miniMapSection: some View {
        Map(position: .constant(.region(MKCoordinateRegion(
            center: live.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )))) {
            Annotation("", coordinate: live.coordinate) {
                Image(systemName: "pawprint.fill")
                    .font(.title2).foregroundStyle(.orange)
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Helpers

    private func likeToggle() {
        let newLiked = !isLiked
        isLiked = newLiked
        likeCount += newLiked ? 1 : -1
        Task { try? await supabase.toggleLike(live) }
    }

    private var addPhotoBinding: Binding<UIImage?> {
        Binding(
            get: { nil },
            set: { image in
                guard let image else { return }
                Task { try? await supabase.addPhotos(to: live, images: [image]) }
            }
        )
    }
}
