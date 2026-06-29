import SwiftUI
internal import _LocationEssentials

struct AddCatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseService.self) private var supabase
    @Environment(LocationManager.self) private var locationManager

    @State private var selectedImages: [UIImage] = []
    @State private var note = ""
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var showSourcePicker = false
    @State private var errorMessage: String?

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

                Section("메모 (선택)") {
                    TextField("이 고양이에 대해 적어보세요", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("현재 위치") {
                    if let loc = locationManager.location {
                        Label(
                            String(format: "%.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude),
                            systemImage: "location.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    note: note
                )
                dismiss()
            } catch {
                errorMessage = "저장에 실패했습니다. 다시 시도해 주세요."
            }
        }
    }
}
