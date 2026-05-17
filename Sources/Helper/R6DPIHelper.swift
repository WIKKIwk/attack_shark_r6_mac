import Foundation
import IOKit.hid

private struct DPIStage {
    let id: Int
    let x: Int
    let y: Int
}

private enum HelperError: Error, CustomStringConvertible {
    case usage
    case deviceNotFound
    case openFailed(IOReturn)
    case reportFailed(String, IOReturn)
    case invalidResponse(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: R6DPIHelper apply-dpi <dpi>"
        case .deviceNotFound:
            return "ATTACK SHARK R6 HID endpoint topilmadi"
        case .openFailed(let code):
            return "HID ochilmadi: \(code)"
        case .reportFailed(let action, let code):
            return "\(action) bajarilmadi: \(code)"
        case .invalidResponse(let action):
            return "\(action) uchun noto'g'ri javob"
        }
    }
}

private final class R6HIDHelper {
    private let vendorID = 0x373e
    private let productID = 0x0022
    private let manager: IOHIDManager
    private var device: IOHIDDevice?
    private var hidIndex = 0

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func connect() throws {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            throw HelperError.deviceNotFound
        }
        guard let selected = devices.max(by: { score($0) < score($1) }), score(selected) > 0 else {
            throw HelperError.deviceNotFound
        }

        let open = IOHIDDeviceOpen(selected, IOOptionBits(kIOHIDOptionsTypeNone))
        guard open == kIOReturnSuccess else {
            throw HelperError.openFailed(open)
        }
        device = selected
    }

    func applyDPI(_ dpi: Int) throws {
        let profile = 1
        let targetStage = 5
        let stages = [
            DPIStage(id: 1, x: 800, y: 800),
            DPIStage(id: 2, x: 1200, y: 1200),
            DPIStage(id: 3, x: 3200, y: 3200),
            DPIStage(id: 4, x: 5600, y: 5600),
            DPIStage(id: 5, x: dpi, y: dpi),
            DPIStage(id: 6, x: 42000, y: 42000)
        ]
        try writeDPIStage(profile: profile, stageID: targetStage, dpi: dpi, current: stages)
        Thread.sleep(forTimeInterval: 0.05)
        try setActiveDPIStage(profile: profile, stage: targetStage)
    }

    private func activeDPIStage(profile: Int) throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 1
        request[5] = 130
        request[6] = UInt8(profile)

        let response = try transact(request)
        return Int(response[8 - hidIndex])
    }

    private func dpiStages(profile: Int) throws -> [DPIStage] {
        var request = emptyReport()
        request[2] = 2
        request[3] = 10
        request[4] = 1
        request[5] = 129
        request[6] = UInt8(profile)
        request[7] = 6

        let response = try transact(request, delay: 0.1)
        guard response.count > 9, response[6 - hidIndex] == 129 else {
            throw HelperError.invalidResponse("DPI stage o'qish")
        }

        let count = Int(response[8 - hidIndex])
        guard count > 0, count <= 10 else {
            throw HelperError.invalidResponse("DPI stage soni")
        }

        return (0..<count).map { offset in
            let start = 9 + offset * 4 - hidIndex
            let x = Int(response[start]) << 8 | Int(response[start + 1])
            let y = Int(response[start + 2]) << 8 | Int(response[start + 3])
            return DPIStage(id: offset + 1, x: x, y: y)
        }
    }

    private func writeDPIStage(profile: Int, stageID: Int, dpi: Int, current: [DPIStage]) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 26
        request[4] = 1
        request[5] = 1
        request[6] = UInt8(profile)
        request[7] = UInt8(current.count)

        for stage in current {
            let value = stage.id == stageID ? dpi : stage.x
            let index = 8 + (stage.id - 1) * 4
            request[index] = UInt8((value >> 8) & 0xff)
            request[index + 1] = UInt8(value & 0xff)
            request[index + 2] = UInt8((value >> 8) & 0xff)
            request[index + 3] = UInt8(value & 0xff)
        }

        try sendReport(request)
    }

    private func setActiveDPIStage(profile: Int, stage: Int) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 1
        request[5] = 2
        request[6] = UInt8(profile)
        request[7] = UInt8(stage)

        try sendReport(request)
    }

    private func transact(_ report: [UInt8], delay: TimeInterval = 0.05) throws -> [UInt8] {
        try sendReport(report)
        Thread.sleep(forTimeInterval: delay)
        let response = try readFeatureReport()
        if response.count > 1, response[1 - hidIndex] == 161 || response[1 - hidIndex] == 2 {
            return response
        }
        throw HelperError.invalidResponse("Mouse javobi")
    }

    private func sendReport(_ report: [UInt8]) throws {
        guard let device else {
            throw HelperError.deviceNotFound
        }
        var output = report
        let outputLength = output.count
        let result = output.withUnsafeMutableBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(0), $0.baseAddress!, outputLength)
        }
        guard result == kIOReturnSuccess else {
            throw HelperError.reportFailed("Mouse'ga yozish", result)
        }
    }

    private func readFeatureReport() throws -> [UInt8] {
        guard let device else {
            throw HelperError.deviceNotFound
        }
        var input = [UInt8](repeating: 0, count: 64)
        var length = input.count
        let result = input.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(0), $0.baseAddress!, &length)
        }
        guard result == kIOReturnSuccess else {
            throw HelperError.reportFailed("Mouse'dan o'qish", result)
        }
        let response = Array(input.prefix(length))
        if response.first == 161 || response.first == 2 {
            return [0] + response
        }
        return response
    }

    private func score(_ device: IOHIDDevice) -> Int {
        var result = 0
        if hasFeatureReport64(device) {
            result += 500
        }
        if intProperty(device, kIOHIDPrimaryUsagePageKey as CFString) == 0xffff {
            result += 100
        }
        if productName(device).localizedCaseInsensitiveContains("R6") {
            result += 50
        }
        if productName(device).localizedCaseInsensitiveContains("Mouse") {
            result += 10
        }
        return result
    }

    private func hasFeatureReport64(_ device: IOHIDDevice) -> Bool {
        guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else {
            return false
        }
        return elements.contains { element in
            IOHIDElementGetType(element) == kIOHIDElementTypeFeature &&
                IOHIDElementGetReportID(element) == 0 &&
                IOHIDElementGetReportCount(element) == 64
        }
    }

    private func productName(_ device: IOHIDDevice) -> String {
        IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
    }

    private func intProperty(_ device: IOHIDDevice, _ key: CFString) -> Int? {
        (IOHIDDeviceGetProperty(device, key) as? NSNumber)?.intValue
    }

    private func emptyReport() -> [UInt8] {
        [UInt8](repeating: 0, count: 64)
    }
}

do {
    let args = CommandLine.arguments
    guard args.count == 3, args[1] == "apply-dpi", let dpi = Int(args[2]), dpi >= 100, dpi <= 42_000 else {
        throw HelperError.usage
    }

    let helper = R6HIDHelper()
    try helper.connect()
    try helper.applyDPI(dpi)
    print("OK \(dpi)")
    exit(0)
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
