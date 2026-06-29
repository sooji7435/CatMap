import SwiftUI
import UniformTypeIdentifiers

struct CatShareCard: View {
    let sighting: CatSighting

    var body: some View {
        VStack(spacing: 0) {
            photoArea
            infoArea
        }
        .frame(width: 360)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private var photoArea: some View {
        Group {
            if let url = sighting.firstPhotoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: 360, height: 260)
        .clipped()
    }

    private var placeholder: some View {
        Color.orange.opacity(0.2)
            .overlay(Text("🐱").font(.system(size: 72)))
    }

    private var infoArea: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(sighting.name ?? "이름 없는 고양이")
                    .font(.title3.bold())

                if let s = sighting.catStatus {
                    Label(s.label, systemImage: s.systemImage)
                        .font(.caption.bold())
                        .foregroundStyle(s.color)
                }

                Label(
                    sighting.locationName ?? String(format: "%.4f°, %.4f°", sighting.latitude, sighting.longitude),
                    systemImage: "location.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(sighting.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("🐾").font(.title)
                Text("길냥이 지도")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
    }

}

/// ShareLink용 Transferable PNG 래퍼
struct CatCardTransferable: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.image.pngData() ?? Data() }
    }
}
