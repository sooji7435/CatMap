import SwiftUI

struct ClusterPinView: View {
    let count: Int
    let scale: Double

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(.orange)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Text("🐱").font(.title3)
            }
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.red)
                .clipShape(Capsule())
                .offset(x: 6, y: -4)
        }
        .scaleEffect(scale)
        .animation(.easeOut(duration: 0.15), value: scale)
    }
}
