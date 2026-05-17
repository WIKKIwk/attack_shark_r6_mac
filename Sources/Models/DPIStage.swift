import Foundation

struct DPIStage: Identifiable, Equatable, Sendable {
    let id: Int
    var x: Int
    var y: Int

    var label: String { "\(x) DPI" }
}
