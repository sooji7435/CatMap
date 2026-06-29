import SwiftUI
import MapKit

struct CatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseService.self) private var supabase

    let sighting: CatSighting

    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    photoSection
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
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .alert("삭제할까요?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    Task {
                        try? await supabase.deleteSighting(sighting)
                        dismiss()
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 길냥이 기록이 삭제됩니다.")
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        if let urlString = sighting.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                case .failure:
                    Color.gray.opacity(0.2)
                        .frame(height: 200)
                        .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
                default:
                    Color.gray.opacity(0.1)
                        .frame(height: 200)
                        .overlay(ProgressView())
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !sighting.note.isEmpty {
                Text(sighting.note)
                    .font(.body)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label(sighting.date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                Label(
                    String(format: "%.5f, %.5f", sighting.latitude, sighting.longitude),
                    systemImage: "location"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var miniMapSection: some View {
        Map(position: .constant(.region(MKCoordinateRegion(
            center: sighting.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )))) {
            Annotation("", coordinate: sighting.coordinate) {
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
        .padding(.horizontal)
        .padding(.bottom)
    }
}
