import SwiftUI
internal import _LocationEssentials

struct AddCatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseService.self) private var supabase
    @Environment(LocationManager.self) private var locationManager

    @State private var selectedImage: UIImage?
    @State private var note = ""
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var showSourcePicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets())
                    }

                    Button {
                        showSourcePicker = true
                    } label: {
                        Label(
                            selectedImage == nil ? "사진 추가" : "사진 변경",
                            systemImage: "camera"
                        )
                    }
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
                            .disabled(selectedImage == nil || locationManager.location == nil)
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
                ImagePicker(image: $selectedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showGallery) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                    .ignoresSafeArea()
            }
        }
    }

    private func save() {
        guard let location = locationManager.location else { return }
        errorMessage = nil
        Task {
            do {
                try await supabase.addSighting(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    image: selectedImage,
                    note: note
                )
                dismiss()
            } catch {
                errorMessage = "저장에 실패했습니다. 다시 시도해 주세요."
            }
        }
    }
}
