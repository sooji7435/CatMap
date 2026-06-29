import SwiftUI
import CoreLocation

struct AddCatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseService.self) private var supabase
    @Environment(LocationManager.self) private var locationManager

    @State private var selectedImages: [UIImage] = []
    @State private var detectionResults: [Bool?] = []   // nil=탐지중, true=고양이, false=없음
    @State private var catName = ""
    @State private var note = ""
    @State private var catStatus: CatStatus? = nil
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var showSourcePicker = false
    @State private var showSaveWarning = false
    @State private var errorMessage: String?
    @State private var locationName: String?

    private let maxPhotos = 5

    private var isDetecting: Bool { detectionResults.contains(where: { $0 == nil }) }
    private var failedCount: Int { detectionResults.filter { $0 == false }.count }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                nameSection
                statusSection
                noteSection
                locationSection
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
                            .disabled(selectedImages.isEmpty || locationManager.location == nil || isDetecting)
                            .bold()
                    }
                }
            }
            .confirmationDialog("사진 선택", isPresented: $showSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("카메라로 찍기") { showCamera = true }
                }
                Button("앨범에서 선택") { showGallery = true }
                Button("취소", role: .cancel) {}
            }
            .alert("고양이가 없는 사진이 있어요", isPresented: $showSaveWarning) {
                Button("계속 저장", role: .destructive) { performSave() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("고양이가 아닌 사진이 포함되어 있습니다. 그래도 저장할까요?")
            }
            .task {
                guard let loc = locationManager.location else { return }
                locationName = await geocode(loc)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: photoBinding, sourceType: .camera).ignoresSafeArea()
            }
            .sheet(isPresented: $showGallery) {
                ImagePicker(image: photoBinding, sourceType: .photoLibrary).ignoresSafeArea()
            }
            .alert("저장 실패", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(photoBorderColor(index), lineWidth: 2)
                                )
                                .overlay(alignment: .bottomLeading) {
                                    photoStatusIcon(index)
                                }

                            Button {
                                selectedImages.remove(at: index)
                                if index < detectionResults.count {
                                    detectionResults.remove(at: index)
                                }
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
                        Button { showSourcePicker = true } label: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus").font(.title2)
                                        Text("추가").font(.caption2)
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

            detectionStatusRow
        }
    }

    private var detectionStatusRow: some View {
        HStack(spacing: 6) {
            if isDetecting {
                ProgressView().scaleEffect(0.75)
                Text("고양이 탐지 중...")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if failedCount > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("고양이를 탐지하지 못했어요 (\(failedCount)장)")
                    .font(.caption2).foregroundStyle(.red)
            } else if !selectedImages.isEmpty {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("고양이 자동 탐지 완료")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Image(systemName: "pawprint.fill").foregroundStyle(.orange)
                Text("고양이 자동 탐지")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()
            Text("\(selectedImages.count) / \(maxPhotos)장")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var nameSection: some View {
        Section("이름 / 별명 (선택)") {
            TextField("예) 삼색이, 까망이, 턱시도", text: $catName)
        }
    }

    private var statusSection: some View {
        Section("상태 (선택)") {
            ForEach(CatStatus.allCases, id: \.self) { s in
                Button {
                    catStatus = catStatus == s ? nil : s
                } label: {
                    HStack {
                        Image(systemName: s.systemImage)
                            .foregroundStyle(s.color)
                            .frame(width: 20)
                        Text(s.label)
                        Spacer()
                        if catStatus == s {
                            Image(systemName: "checkmark").foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var noteSection: some View {
        Section("메모 (선택)") {
            TextField("이 고양이에 대해 적어보세요", text: $note, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var locationSection: some View {
        Section("현재 위치") {
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                Label("위치 권한이 없습니다", systemImage: "location.slash.fill")
                    .foregroundStyle(.red)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("설정에서 허용하기", systemImage: "gear")
                        .foregroundStyle(.orange)
                }
            default:
                if locationManager.location != nil {
                    Label(locationName ?? "위치 확인 중...", systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(locationName == nil ? .secondary : .primary)
                } else {
                    Label("위치를 가져오는 중...", systemImage: "location.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Photo helpers

    @ViewBuilder
    private func photoStatusIcon(_ index: Int) -> some View {
        if index < detectionResults.count {
            switch detectionResults[index] {
            case false:
                Image(systemName: "exclamationmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .font(.caption)
                    .padding(4)
            case nil:
                ProgressView().scaleEffect(0.5).padding(4)
            default:
                EmptyView()
            }
        }
    }

    private func photoBorderColor(_ index: Int) -> Color {
        guard index < detectionResults.count else { return .clear }
        switch detectionResults[index] {
        case false: return .red
        case nil:   return Color(.systemGray3)
        default:    return .clear
        }
    }

    // MARK: - Bindings & actions

    private var photoBinding: Binding<UIImage?> {
        Binding(
            get: { nil },
            set: { image in
                guard let image else { return }
                selectedImages.append(image)
                detectionResults.append(nil)
                let idx = selectedImages.count - 1

                Task {
                    let isCat = await CatDetector.containsCat(in: image)
                    if idx < detectionResults.count {
                        detectionResults[idx] = isCat
                    }
                }
            }
        )
    }

    private func geocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                guard let p = placemarks?.first else { continuation.resume(returning: nil); return }
                let parts = [p.locality, p.subLocality].compactMap { $0 }
                continuation.resume(returning: parts.isEmpty ? nil : parts.joined(separator: " "))
            }
        }
    }

    private func save() {
        guard locationManager.location != nil else { return }
        if failedCount > 0 {
            showSaveWarning = true
            return
        }
        performSave()
    }

    private func performSave() {
        guard let location = locationManager.location else { return }
        errorMessage = nil
        Task {
            do {
                try await supabase.addSighting(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    images: selectedImages,
                    name: catName.isEmpty ? nil : catName,
                    note: note,
                    status: catStatus?.rawValue
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
