import Foundation

enum R6Error: LocalizedError {
    case deviceNotFound
    case openFailed(IOReturn)
    case reportFailed(String, IOReturn)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "ATTACK SHARK R6 topilmadi. 2.4G dongle yoki USB-C orqali ulang."
        case .openFailed(let code):
            return "Mouse HID ochilmadi. IOReturn: \(code)"
        case .reportFailed(let action, let code):
            return "\(action) bajarilmadi. IOReturn: \(code)"
        case .invalidResponse(let action):
            return "\(action) uchun mouse noto'g'ri javob qaytardi."
        }
    }
}
