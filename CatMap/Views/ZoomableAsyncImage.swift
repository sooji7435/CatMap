import SwiftUI

struct ZoomableAsyncImage: View {
    let url: URL

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(zoomGesture.simultaneously(with: dragGesture))
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1; lastScale = 1
                                offset = .zero; lastOffset = .zero
                            } else {
                                scale = 2.5; lastScale = 2.5
                            }
                        }
                    }
            case .failure:
                Color.gray.opacity(0.15)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
            default:
                Color.gray.opacity(0.1).overlay(ProgressView())
            }
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in scale = max(1, lastScale * value) }
            .onEnded { _ in
                lastScale = scale
                if scale < 1 { withAnimation { scale = 1; lastScale = 1 } }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }
}
