import SwiftUI

private final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func get(_ url: URL) -> UIImage? { cache.object(forKey: url.absoluteString as NSString) }
    func set(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url.absoluteString as NSString) }
}

@MainActor
private final class ImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    private var loadedURL: URL?
    private var task: Task<Void, Never>?

    func load(_ url: URL) {
        guard url != loadedURL else { return }
        loadedURL = url

        if let cached = ImageCache.shared.get(url) {
            image = cached
            return
        }

        task?.cancel()
        task = Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = UIImage(data: data),
                  !Task.isCancelled else { return }
            ImageCache.shared.set(img, for: url)
            image = img
        }
    }

    func reset() {
        task?.cancel(); task = nil; loadedURL = nil; image = nil
    }
}

/// AsyncImage 대체 - NSCache 기반 인메모리 캐싱 지원
struct CachedAsyncImage: View {
    let url: URL?

    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img).resizable()
            } else {
                Color.gray.opacity(0.1)
                    .overlay(ProgressView().scaleEffect(0.6))
            }
        }
        .onChange(of: url, initial: true) { _, newURL in
            if let u = newURL { loader.load(u) } else { loader.reset() }
        }
    }
}
