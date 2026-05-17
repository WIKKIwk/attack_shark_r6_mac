import SwiftUI

struct R6Snapshot: Sendable {
    let firmware: String
    let profile: Int
    let activeStage: Int
    let stages: [DPIStage]
    let sensor: SensorSettings
}

final class R6ViewModel: ObservableObject, @unchecked Sendable {
    @Published var firmware = "-"
    @Published var profile = 0
    @Published var activeStage = 0
    @Published var stages: [DPIStage] = []
    @Published var selectedDPI = 2400.0
    @Published var sensor = SensorSettings()
    @Published var status = "R6 ulanmagan"
    @Published var isBusy = false
    @Published var isConnected = false

    private let hid = R6HID()
    private let workQueue = DispatchQueue(label: "local.wikki.r6dpi.hid", qos: .userInitiated)

    var activeDPI: Int {
        stages.first(where: { $0.id == activeStage })?.x ?? 0
    }

    func connect() {
        status = "Tayyor. Apply DPI helper orqali ishlaydi."
        isBusy = false
    }

    func refresh() {
        status = "Readback vaqtincha o'chirilgan. Tizim osilmasligi uchun faqat Apply DPI ishlaydi."
        isBusy = false
    }

    func applySelectedDPI() {
        let dpi = clamp(Int(selectedDPI.rounded()))
        run("\(dpi) DPI yozilmoqda...") { _ in
            _ = try Self.runHelper(["apply-dpi", "\(dpi)"])
            return (nil, "\(dpi) DPI helper orqali yozildi", true)
        }
    }

    func activate(stage: DPIStage) {
        status = "\(stage.label) uchun stage switch vaqtincha o'chirilgan. DPI yozish Apply orqali ishlaydi."
    }

    func setLOD(_ value: Int) {
        status = "LOD write vaqtincha o'chirilgan. Avval DPI helper stabil ishlashi kerak."
    }

    func setSensorToggle(_ toggle: SensorToggle, enabled: Bool) {
        status = "Sensor write vaqtincha o'chirilgan. Noto'g'ri HID report tizim inputini buzmasligi kerak."
    }

    func setDebounceTime(_ value: Int) {
        status = "Debounce write vaqtincha o'chirilgan. Avval DPI helper stabil ishlashi kerak."
    }

    func setSleepTime(_ value: Int) {
        status = "Sleep write vaqtincha o'chirilgan. Avval DPI helper stabil ishlashi kerak."
    }

    func setButtonCombine(enabled: Bool) {
        status = "Combo keys write vaqtincha o'chirilgan. Noto'g'ri HID report tizim inputini buzmasligi kerak."
    }

    private static func readSnapshot(from hid: R6HID) throws -> R6Snapshot {
        let firmware = try hid.firmwareVersion()
        let profile = try hid.profileID()
        let stages = try hid.dpiStages(profile: profile)
        let activeStage = try hid.activeDPIStage(profile: profile)
        let sensor = (try? hid.sensorSettings(profile: profile)) ?? SensorSettings()
        return R6Snapshot(firmware: firmware, profile: profile, activeStage: activeStage, stages: stages, sensor: sensor)
    }

    private static func connectWithRetry(_ hid: R6HID) throws {
        var lastError: Error?
        for attempt in 0..<6 {
            do {
                try hid.connect()
                return
            } catch {
                lastError = error
                if attempt < 5 {
                    Thread.sleep(forTimeInterval: 0.18)
                }
            }
        }
        throw lastError ?? R6Error.deviceNotFound
    }

    private static func runHelper(_ arguments: [String], timeout: TimeInterval = 3) throws -> String {
        let executable = Bundle.main.url(forAuxiliaryExecutable: "R6DPIHelper")
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/R6DPIHelper")
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let done = DispatchSemaphore(value: 0)

        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { _ in
            done.signal()
        }

        try process.run()
        if done.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw R6Error.invalidResponse("HID helper timeout")
        }

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw R6Error.invalidResponse(error.isEmpty ? output : error)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func apply(_ snapshot: R6Snapshot) {
        firmware = snapshot.firmware
        profile = snapshot.profile
        stages = snapshot.stages
        activeStage = snapshot.activeStage
        sensor = snapshot.sensor
        if let active = snapshot.stages.first(where: { $0.id == snapshot.activeStage }) {
            selectedDPI = Double(active.x)
        }
    }

    private func run(
        _ busyStatus: String,
        _ action: @escaping @Sendable (R6HID) throws -> (R6Snapshot?, String, Bool)
    ) {
        isBusy = true
        status = busyStatus
        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let result = try action(self.hid)
                DispatchQueue.main.async {
                    if let snapshot = result.0 {
                        self.apply(snapshot)
                    }
                    self.status = result.1
                    self.isConnected = result.2
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = error.localizedDescription
                    self.isConnected = false
                    self.isBusy = false
                }
            }
        }
    }

    private func clamp(_ value: Int) -> Int {
        min(max(value, 100), 42_000)
    }
}
