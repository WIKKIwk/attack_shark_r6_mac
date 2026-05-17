import Foundation
import IOKit.hid

final class R6HID: @unchecked Sendable {
    let vendorID = 0x373e
    let productID = 0x0022
    let preferredUsagePage = 0xffff
    let manager: IOHIDManager
    var device: IOHIDDevice?
    var hidIndex = 0

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        disconnect()
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func connect() throws {
        disconnect()

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let managerOpen = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            if managerOpen != kIOReturnSuccess {
                throw R6Error.openFailed(managerOpen)
            }
            throw R6Error.deviceNotFound
        }

        let sorted = devices.sorted { lhs, rhs in
            let lhsScore = score(lhs)
            let rhsScore = score(rhs)
            if lhsScore == rhsScore {
                return productName(lhs) < productName(rhs)
            }
            return lhsScore > rhsScore
        }

        guard let selected = sorted.first(where: { score($0) > 0 }) else {
            throw R6Error.deviceNotFound
        }

        let deviceOpen = IOHIDDeviceOpen(selected, IOOptionBits(kIOHIDOptionsTypeNone))
        guard deviceOpen == kIOReturnSuccess else {
            throw R6Error.openFailed(deviceOpen)
        }

        device = selected
    }

    func disconnect() {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        hidIndex = 0
    }

}
