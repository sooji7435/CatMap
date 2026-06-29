import SwiftUI

extension CatStatus {
    var color: Color {
        switch self {
        case .healthy: return .green
        case .injured: return .red
        case .kitten:  return .blue
        }
    }
}
