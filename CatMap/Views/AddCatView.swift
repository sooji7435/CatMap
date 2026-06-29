import SwiftUI
import CoreLocation
internal import _LocationEssentials

struct AddCatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseService.self) private var supabase
    @Environment(LocationManager.self) private var locationManager

    @State private var selectedImages: [UIImage] = []
    @State private var catName = ""
    @State private var note = ""
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var showSourcePicker = false
    @State private var errorMessage: String?
    @State private var locationName: String?

    private let maxPhotos = 5

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Button {
                                        selectedImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, Color.black.opacity(0.55))
                                            .font(.title3)
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }

                            if selectedImages.count < maxPhotos {
                                Button {
                                    showSourcePicker = true
                                } label: {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 80, height: 80)
                                        .overlay {
                                            VStack(spacing: 4) {
                                                Image(systemName: "plus")
                                                    .font(.title2)
                                                Text("추가")
                                                    .font(.caption2)
                                            }
                                            .foregroundStyle(.secondary)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                    Text("\(selectedImages.count) / \(maxPhotos)장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("이름 / 별명 (선택)") {
                    TextField("예) 삼색이, 까망이, 턱시도", text: $catName)
                }

                Section("메모 (선택)") {
                    TextField("이 고양이에 대해 적어보세요", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("현재 위치") {
                    if locationManager.location != nil {
                        Label(locationName ?? "위치 확인 중...", systemImage: "location.fill")
                            .font(.subheadline)
                            .foregroundStyle(locationName == nil ? .secondary : .primary)
                    } else {
                        Label("위치를 가져오는 중...", systemImage: "location.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("길냥이 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .disabled(supabase.isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if supabase.isUploading {
                        ProgressView()
                    } else {
                        Button("저장") { save() }
                            .disabled(selectedImages.isEmpty || locationManager.location == nil)
                            .bold()
                    }
                }
            }
            .confirmationDialog("사진 선택", isPresented: $showSourcePicker) {
                Button("카메라로 찍기") { showCamera = true }
                Button("앨범에서 선택") { showGallery = true }
                Button("취소", role: .cancel) {}
            }
            .task {
                guard let loc = locationManager.location else { return }
                locationName = await geocode(loc)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: singleImageBinding, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showGallery) {
                ImagePicker(image: singleImageBinding, sourceType: .photoLibrary)
                    .ignoresSafeArea()
            }
        }
    }

    private func geocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                guard let p = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let parts = [p.locality, p.subLocality].compactMap { $0 }
                continuation.resume(returning: parts.isEmpty ? nil : parts.joined(separator: " "))
            }
        }
    }

    private var singleImageBinding: Binding<UIImage?> {
        Binding(
            get: { nil },
            set: { if let img = $0 { selectedImages.append(img) } }
        )
    }

    private func save() {
        guard let location = locationManager.location else { return }
        errorMessage = nil
        Task {
            do {
                try await supabase.addSighting(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    images: selectedImages,
                    name: catName.isEmpty ? nil : catName,
                    note: note
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
