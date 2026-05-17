import Foundation

struct SensorSettings: Sendable {
    var sensorModel: String = "-"
    var batteryPercent = 0
    var lod: Int = 1
    var pollingRateCode = 0
    var debounceTime = 0
    var sleepTime = 0
    var motionSync = false
    var angleSnap = false
    var rippleControl = false
    var trackingMode = false
    var hyperMode = false
    var dpiIndicator = false
    var dpiXY = false
    var buttonCombine = false
}

enum SensorToggle: Sendable {
    case motionSync
    case angleSnap
    case rippleControl
    case trackingMode
    case hyperMode
    case dpiIndicator
    case dpiXY

    var setCode: UInt8 {
        switch self {
        case .motionSync: return 9
        case .angleSnap: return 4
        case .rippleControl: return 10
        case .trackingMode: return 19
        case .hyperMode: return 11
        case .dpiIndicator: return 4
        case .dpiXY: return 13
        }
    }

    var getCode: UInt8 {
        switch self {
        case .motionSync: return 137
        case .angleSnap: return 132
        case .rippleControl: return 138
        case .trackingMode: return 147
        case .hyperMode: return 139
        case .dpiIndicator: return 132
        case .dpiXY: return 141
        }
    }

    var commandGroup: UInt8 {
        switch self {
        case .dpiIndicator: return 2
        default: return 1
        }
    }
}
