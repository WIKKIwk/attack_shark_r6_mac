import Foundation
import IOKit.hid

extension R6HID {
    func sendReport(_ report: [UInt8]) throws {
        guard let device else {
            throw R6Error.deviceNotFound
        }

        var output = report
        let outputLength = output.count
        let setResult = output.withUnsafeMutableBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(0), $0.baseAddress!, outputLength)
        }
        guard setResult == kIOReturnSuccess else {
            throw R6Error.reportFailed("Mouse'ga yozish", setResult)
        }
    }

    func transact(_ report: [UInt8], delayNanoseconds: UInt64 = 50_000_000) throws -> [UInt8] {
        guard let device else {
            throw R6Error.deviceNotFound
        }

        var lastReadError: Error?

        for _ in 0..<3 {
            var output = report

            let outputLength = output.count
            let setResult = output.withUnsafeMutableBufferPointer {
                IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(0), $0.baseAddress!, outputLength)
            }
            guard setResult == kIOReturnSuccess else {
                throw R6Error.reportFailed("Mouse'ga yozish", setResult)
            }

            Thread.sleep(forTimeInterval: Double(delayNanoseconds) / 1_000_000_000)

            for _ in 0..<10 {
                do {
                    let response = try readFeatureReport(from: device)
                    if isReady(response) {
                        return response
                    }
                } catch {
                    lastReadError = error
                }
                Thread.sleep(forTimeInterval: 0.03)
            }
        }

        if let lastReadError {
            throw lastReadError
        }
        throw R6Error.invalidResponse("Mouse javobi")
    }

    func readFeatureReport(from device: IOHIDDevice) throws -> [UInt8] {
        var input = [UInt8](repeating: 0, count: 64)
        var length = input.count
        let result = input.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(0), $0.baseAddress!, &length)
        }
        guard result == kIOReturnSuccess else {
            throw R6Error.reportFailed("Mouse'dan o'qish", result)
        }
        let response = Array(input.prefix(length))
        if response.first == 161 || response.first == 2 {
            return [0] + response
        }
        return response
    }

    func isReady(_ response: [UInt8]) -> Bool {
        guard response.count > 1 else { return false }
        return response[1 - hidIndex] == 161 || response[1 - hidIndex] == 2
    }

    func emptyReport() -> [UInt8] {
        [UInt8](repeating: 0, count: 64)
    }

    func score(_ device: IOHIDDevice) -> Int {
        var result = 0
        if hasFeatureReport64(device) {
            result += 500
        }
        if intProperty(device, kIOHIDPrimaryUsagePageKey as CFString) == preferredUsagePage {
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

    func hasFeatureReport64(_ device: IOHIDDevice) -> Bool {
        guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else {
            return false
        }
        return elements.contains { element in
            IOHIDElementGetType(element) == kIOHIDElementTypeFeature &&
                IOHIDElementGetReportID(element) == 0 &&
                IOHIDElementGetReportCount(element) == 64
        }
    }

    func productName(_ device: IOHIDDevice) -> String {
        IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
    }

    func intProperty(_ device: IOHIDDevice, _ key: CFString) -> Int? {
        if let number = IOHIDDeviceGetProperty(device, key) as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
