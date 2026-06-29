import SwiftUI

struct CatPinView: View {
    let sighting: CatSighting
    let isAnimating: Bool
    let scale: Double

    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 2) {
            if let name = sighting.name, !name.isEmpty {
                Text(name)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }

            ZStack(alignment: .topTrailing) {
                pinCircle
                if sighting.isNew {
                    newBadge
                }
            }
        }
        .scaleEffect(scale * (isAnimating ? 1.35 : 1.0))
        .animation(.easeOut(duration: 0.15), value: scale)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isAnimating)
    }

    @ViewBuilder
    private var pinCircle: some View {
        ZStack {
            if sighting.catStatus == .injured {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: 58, height: 58)
                    .opacity(pulseOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseOpacity = 0.15
                        }
                    }
            }

            if let url = sighting.firstPhotoURL {
                CachedAsyncImage(url: url)
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(sighting.catStatus?.color ?? .white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            } else {
                catEmoji
            }
        }
    }

    private var catEmoji: some View {
        ZStack {
            Circle()
                .fill(.orange)
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Text("🐱").font(.title3)
        }
    }

    private var newBadge: some View {
        Text("NEW")
            .font(.system(size: 7, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.green)
            .clipShape(Capsule())
            .offset(x: 8, y: -4)
    }
}
