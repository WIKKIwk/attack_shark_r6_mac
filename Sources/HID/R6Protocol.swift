import Foundation

extension R6HID {
    func firmwareVersion() throws -> String {
        var request = emptyReport()
        request[2] = 2
        request[3] = 16
        request[5] = 129

        let response = try transact(request, delayNanoseconds: 100_000_000)
        if response.count > 10, response[6] == 129 {
            hidIndex = 0
            return "\(response[7]).\(response[8]).\(response[9]).\(response[10])"
        }
        if response.count > 9, response[5] == 129 {
            hidIndex = 1
            return "\(response[6]).\(response[7]).\(response[8]).\(response[9])"
        }
        throw R6Error.invalidResponse("Firmware o'qish")
    }

    func profileID() throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 1
        request[5] = 133

        let response = try transact(request)
        return Int(response[7 - hidIndex])
    }

    func activeDPIStage(profile: Int) throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 1
        request[5] = 130
        request[6] = UInt8(profile)

        let response = try transact(request)
        return Int(response[8 - hidIndex])
    }

    func setActiveDPIStage(profile: Int, stage: Int) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 1
        request[5] = 2
        request[6] = UInt8(profile)
        request[7] = UInt8(stage)

        try sendReport(request)
    }

    func dpiStages(profile: Int) throws -> [DPIStage] {
        var request = emptyReport()
        request[2] = 2
        request[3] = 10
        request[4] = 1
        request[5] = 129
        request[6] = UInt8(profile)
        request[7] = 6

        let response = try transact(request, delayNanoseconds: 100_000_000)
        guard response.count > 9, response[6 - hidIndex] == 129 else {
            throw R6Error.invalidResponse("DPI stage o'qish")
        }

        let count = Int(response[8 - hidIndex])
        guard count > 0, count <= 10 else {
            throw R6Error.invalidResponse("DPI stage soni")
        }

        return (0..<count).map { offset in
            let start = 9 + offset * 4 - hidIndex
            let x = Int(response[start]) << 8 | Int(response[start + 1])
            let y = Int(response[start + 2]) << 8 | Int(response[start + 3])
            return DPIStage(id: offset + 1, x: x, y: y)
        }
    }

    func writeDPIStage(profile: Int, stageID: Int, dpi: Int) throws {
        let fallback = [
            DPIStage(id: 1, x: 800, y: 800),
            DPIStage(id: 2, x: 1200, y: 1200),
            DPIStage(id: 3, x: 3200, y: 3200),
            DPIStage(id: 4, x: 5600, y: 5600),
            DPIStage(id: 5, x: 2400, y: 2400),
            DPIStage(id: 6, x: 42000, y: 42000)
        ]
        let current = fallback
        guard current.contains(where: { $0.id == stageID }) else {
            throw R6Error.invalidResponse("DPI stage tanlash")
        }

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

    func sensorSettings(profile: Int) throws -> SensorSettings {
        SensorSettings(
            sensorModel: try sensorModelName(),
            batteryPercent: try batteryPercent(),
            lod: try getByteFeature(profile: profile, code: 136),
            pollingRateCode: try pollingRateCode(profile: profile),
            debounceTime: try debounceTime(profile: profile),
            sleepTime: try sleepTime(profile: profile),
            motionSync: try getBoolFeature(profile: profile, toggle: .motionSync),
            angleSnap: try getBoolFeature(profile: profile, toggle: .angleSnap),
            rippleControl: try getBoolFeature(profile: profile, toggle: .rippleControl),
            trackingMode: try getBoolFeature(profile: profile, toggle: .trackingMode),
            hyperMode: try getBoolFeature(profile: profile, toggle: .hyperMode),
            dpiIndicator: try getBoolFeature(profile: profile, toggle: .dpiIndicator),
            dpiXY: try getBoolFeature(profile: profile, toggle: .dpiXY),
            buttonCombine: try buttonCombine(profile: profile)
        )
    }

    func setLOD(profile: Int, value: Int) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 1
        request[5] = 8
        request[6] = UInt8(profile)
        request[7] = UInt8(value)

        try sendReport(request)
    }

    func setSensorToggle(profile: Int, toggle: SensorToggle, enabled: Bool) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = toggle.commandGroup
        request[5] = toggle.setCode
        request[6] = UInt8(profile)
        request[7] = enabled ? 1 : 0

        try sendReport(request)
    }

    func setDebounceTime(profile: Int, value: Int) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[5] = 8
        request[6] = UInt8(profile)
        request[7] = UInt8(value)

        try sendReport(request)
    }

    func setSleepTime(profile: Int, value: Int) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 3
        request[5] = 7
        request[6] = UInt8(profile)
        request[7] = UInt8((value >> 8) & 0xff)
        request[8] = UInt8(value & 0xff)

        try sendReport(request)
    }

    func setButtonCombine(profile: Int, enabled: Bool) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 3
        request[5] = 1
        request[6] = UInt8(profile)
        request[7] = enabled ? 1 : 0

        try sendReport(request)
    }

    private func sensorModelName() throws -> String {
        var request = emptyReport()
        request[2] = 2
        request[3] = 1
        request[4] = 1
        request[5] = 143

        let response = try transact(request)
        let model = Int(response[7 - hidIndex])
        return model == 2 ? "PAW3950MAX" : "Sensor \(model)"
    }

    private func getBoolFeature(profile: Int, toggle: SensorToggle) throws -> Bool {
        try getByteFeature(profile: profile, code: toggle.getCode, group: toggle.commandGroup) == 1
    }

    private func getByteFeature(profile: Int, code: UInt8, group: UInt8 = 1) throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = group
        request[5] = code
        request[6] = UInt8(profile)

        let response = try transact(request)
        return Int(response[8 - hidIndex])
    }

    private func batteryPercent() throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[5] = 131

        let response = try transact(request, delayNanoseconds: 100_000_000)
        if response.count > 8, response[6] == 131 {
            return Int(response[7])
        }
        if response.count > 7, response[5] == 131 {
            return Int(response[6])
        }
        return 0
    }

    private func buttonCombine(profile: Int) throws -> Bool {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 3
        request[5] = 129
        request[6] = UInt8(profile)

        let response = try transact(request)
        return response[8 - hidIndex] == 1
    }

    private func pollingRateCode(profile: Int) throws -> Int {
        var value = try getByteFeature(profile: profile, code: 128)
        if value == 16 {
            value = 1
        }
        return value
    }

    private func debounceTime(profile: Int) throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[5] = 136
        request[6] = UInt8(profile)

        let response = try transact(request)
        return Int(response[8 - hidIndex])
    }

    private func sleepTime(profile: Int) throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 3
        request[5] = 135
        request[6] = UInt8(profile)

        let response = try transact(request)
        return (Int(response[8 - hidIndex]) << 8) + Int(response[9 - hidIndex])
    }

}
