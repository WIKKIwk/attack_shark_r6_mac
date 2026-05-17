import SwiftUI
import IOKit.hid

private struct DPIStage: Identifiable, Equatable, Sendable {
    let id: Int
    var x: Int
    var y: Int

    var label: String { "\(x) DPI" }
}

private struct SensorSettings: Sendable {
    var sensorModel: String = "-"
    var lod: Int = 1
    var motionSync = false
    var angleSnap = false
    var rippleControl = false
    var trackingMode = false
}

private enum SensorToggle: Sendable {
    case motionSync
    case angleSnap
    case rippleControl
    case trackingMode

    var setCode: UInt8 {
        switch self {
        case .motionSync: return 9
        case .angleSnap: return 4
        case .rippleControl: return 10
        case .trackingMode: return 19
        }
    }
}

private enum R6Error: LocalizedError {
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

private final class R6HID: @unchecked Sendable {
    private let vendorID = 0x373e
    private let productID = 0x0022
    private let preferredUsagePage = 0xffff
    private let manager: IOHIDManager
    private var device: IOHIDDevice?
    private var hidIndex = 0

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func connect() throws {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let managerOpen = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerOpen == kIOReturnSuccess else {
            throw R6Error.openFailed(managerOpen)
        }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
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
        _ = try firmwareVersion()
    }

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

        _ = try transact(request)
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
        let current = try dpiStages(profile: profile)
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

        _ = try transact(request)
    }

    func sensorSettings(profile: Int) throws -> SensorSettings {
        SensorSettings(
            sensorModel: try sensorModelName(),
            lod: try getByteFeature(profile: profile, code: 136),
            motionSync: try getBoolFeature(profile: profile, code: 137),
            angleSnap: try getBoolFeature(profile: profile, code: 132),
            rippleControl: try getBoolFeature(profile: profile, code: 138),
            trackingMode: try getBoolFeature(profile: profile, code: 147)
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

        _ = try transact(request)
    }

    func setSensorToggle(profile: Int, toggle: SensorToggle, enabled: Bool) throws {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 1
        request[5] = toggle.setCode
        request[6] = UInt8(profile)
        request[7] = enabled ? 1 : 0

        _ = try transact(request)
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

    private func getBoolFeature(profile: Int, code: UInt8) throws -> Bool {
        try getByteFeature(profile: profile, code: code) == 1
    }

    private func getByteFeature(profile: Int, code: UInt8) throws -> Int {
        var request = emptyReport()
        request[2] = 2
        request[3] = 2
        request[4] = 1
        request[5] = code
        request[6] = UInt8(profile)

        let response = try transact(request)
        return Int(response[8 - hidIndex])
    }

    private func transact(_ report: [UInt8], delayNanoseconds: UInt64 = 50_000_000) throws -> [UInt8] {
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

        Thread.sleep(forTimeInterval: Double(delayNanoseconds) / 1_000_000_000)

        var response = try readFeatureReport(from: device)
        for _ in 0..<30 where !isReady(response) {
            Thread.sleep(forTimeInterval: 0.02)
            response = try readFeatureReport(from: device)
        }

        if !isReady(response) {
            throw R6Error.invalidResponse("Mouse javobi")
        }
        return response
    }

    private func readFeatureReport(from device: IOHIDDevice) throws -> [UInt8] {
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

    private func isReady(_ response: [UInt8]) -> Bool {
        guard response.count > 1 else { return false }
        return response[1 - hidIndex] == 161 || response[1 - hidIndex] == 2
    }

    private func emptyReport() -> [UInt8] {
        [UInt8](repeating: 0, count: 64)
    }

    private func score(_ device: IOHIDDevice) -> Int {
        var result = 0
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

    private func productName(_ device: IOHIDDevice) -> String {
        IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
    }

    private func intProperty(_ device: IOHIDDevice, _ key: CFString) -> Int? {
        if let number = IOHIDDeviceGetProperty(device, key) as? NSNumber {
            return number.intValue
        }
        return nil
    }
}

private struct R6Snapshot: Sendable {
    let firmware: String
    let profile: Int
    let activeStage: Int
    let stages: [DPIStage]
    let sensor: SensorSettings
}

private final class R6ViewModel: ObservableObject, @unchecked Sendable {
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
        run("Ulanmoqda...") { hid in
            try Self.connectWithRetry(hid)
            let snapshot = try Self.readSnapshot(from: hid)
            return (snapshot, "R6 ulandi", true)
        }
    }

    func refresh() {
        run("Yangilanmoqda...") { hid in
            let snapshot = try Self.readSnapshot(from: hid)
            return (snapshot, "Sozlamalar o'qildi", true)
        }
    }

    func applySelectedDPI() {
        let dpi = clamp(Int(selectedDPI.rounded()))
        let connected = isConnected
        run("\(dpi) DPI yozilmoqda...") { hid in
            if !connected {
                try Self.connectWithRetry(hid)
            }

            var snapshot = try Self.readSnapshot(from: hid)
            let targetStage: Int
            if let exact = snapshot.stages.first(where: { $0.x == dpi }) {
                targetStage = exact.id
            } else if snapshot.activeStage > 0 {
                targetStage = snapshot.activeStage
                try hid.writeDPIStage(profile: snapshot.profile, stageID: targetStage, dpi: dpi)
            } else {
                targetStage = 1
                try hid.writeDPIStage(profile: snapshot.profile, stageID: targetStage, dpi: dpi)
            }

            try hid.setActiveDPIStage(profile: snapshot.profile, stage: targetStage)
            snapshot = try Self.readSnapshot(from: hid)
            return (snapshot, "\(dpi) DPI aktiv qilindi", true)
        }
    }

    func activate(stage: DPIStage) {
        let currentProfile = profile
        run("\(stage.label) aktiv qilinmoqda...") { hid in
            let profile = currentProfile > 0 ? currentProfile : try hid.profileID()
            try hid.setActiveDPIStage(profile: profile, stage: stage.id)
            let snapshot = try Self.readSnapshot(from: hid)
            return (snapshot, "\(stage.label) aktiv", true)
        }
    }

    func setLOD(_ value: Int) {
        let currentProfile = profile
        run("LOD \(value) yozilmoqda...") { hid in
            let profile = currentProfile > 0 ? currentProfile : try hid.profileID()
            try hid.setLOD(profile: profile, value: value)
            let snapshot = try Self.readSnapshot(from: hid)
            return (snapshot, "LOD \(value) aktiv", true)
        }
    }

    func setSensorToggle(_ toggle: SensorToggle, enabled: Bool) {
        let currentProfile = profile
        run("Sensor sozlamasi yozilmoqda...") { hid in
            let profile = currentProfile > 0 ? currentProfile : try hid.profileID()
            try hid.setSensorToggle(profile: profile, toggle: toggle, enabled: enabled)
            let snapshot = try Self.readSnapshot(from: hid)
            return (snapshot, "Sensor sozlamasi saqlandi", true)
        }
    }

    private static func readSnapshot(from hid: R6HID) throws -> R6Snapshot {
        let firmware = try hid.firmwareVersion()
        let profile = try hid.profileID()
        let stages = try hid.dpiStages(profile: profile)
        let activeStage = try hid.activeDPIStage(profile: profile)
        let sensor = try hid.sensorSettings(profile: profile)
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
        _ action: @escaping @Sendable (R6HID) throws -> (R6Snapshot, String, Bool)
    ) {
        isBusy = true
        status = busyStatus
        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let result = try action(self.hid)
                DispatchQueue.main.async {
                    self.apply(result.0)
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

private struct ContentView: View {
    @StateObject private var model = R6ViewModel()
    @State private var selectedPanel = 0

    private let presets = [800, 1200, 1600, 2000, 2400, 2800, 3200, 5600, 8000]
    private let backgroundColor = Color(red: 0.035, green: 0.035, blue: 0.04)
    private let panelColor = Color(red: 0.075, green: 0.075, blue: 0.085)
    private let raisedPanelColor = Color(red: 0.105, green: 0.105, blue: 0.12)
    private let borderColor = Color.white.opacity(0.08)
    private let primaryText = Color(red: 0.92, green: 0.92, blue: 0.90)
    private let secondaryText = Color(red: 0.55, green: 0.56, blue: 0.58)
    private let accentColor = Color(red: 0.76, green: 0.77, blue: 0.78)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                header
                currentCard
                panelPicker
                if selectedPanel == 0 {
                    controls
                    stageGrid
                } else {
                    sensorPanel
                }
                footer
            }
            .padding(18)
        }
        .frame(width: 560, height: 620)
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                model.connect()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(raisedPanelColor)
                    .frame(width: 46, height: 46)
                    .glassEffect(.regular.tint(Color.white.opacity(0.04)).interactive(), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(borderColor)
                    }
                Image(systemName: "computermouse")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(primaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("R6 DPI Studio")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                Text("ATTACK SHARK R6 uchun native macOS controller")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }

            Spacer()
        }
    }

    private var currentCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Active DPI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                    .textCase(.uppercase)
                Text(model.activeDPI > 0 ? "\(model.activeDPI)" : "-")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(primaryText)
                    .contentTransition(.numericText())
                Text("Stage \(model.activeStage == 0 ? "-" : "\(model.activeStage)")  •  Profile \(model.profile == 0 ? "-" : "\(model.profile)")")
                    .font(.callout)
                    .foregroundStyle(secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label(model.isConnected ? "Connected" : "Disconnected", systemImage: model.isConnected ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(model.isConnected ? primaryText : secondaryText)
                Text("Firmware \(model.firmware)")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(18)
        .background(raisedPanelColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular.tint(Color.white.opacity(0.03)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor)
        }
    }

    private var panelPicker: some View {
        Picker("", selection: $selectedPanel) {
            Text("DPI").tag(0)
            Text("Sensor").tag(1)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom DPI")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("\(Int(model.selectedDPI.rounded()))")
                    .font(.headline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(accentColor)
            }

            Slider(value: $model.selectedDPI, in: 100...42000, step: 100)
                .tint(accentColor)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 6) {
                ForEach(presets, id: \.self) { dpi in
                    Button("\(dpi)") {
                        model.selectedDPI = Double(dpi)
                        model.applySelectedDPI()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(accentColor)
                    .glassEffect(.regular.tint(Color.white.opacity(0.03)).interactive(), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }

            HStack {
                Button {
                    model.applySelectedDPI()
                } label: {
                    Label("Apply DPI", systemImage: "bolt.fill")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .tint(accentColor)
                .disabled(model.isBusy)

                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .tint(accentColor)
                .disabled(model.isBusy)

                Button {
                    model.connect()
                } label: {
                    Label("Reconnect", systemImage: "cable.connector")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .tint(accentColor)
                .disabled(model.isBusy)
            }
        }
        .padding(14)
        .background(panelColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .glassEffect(.regular.tint(Color.white.opacity(0.025)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor)
        }
    }

    private var stageGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Onboard Stages")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(model.stages) { stage in
                    Button {
                        model.activate(stage: stage)
                    } label: {
                        VStack(spacing: 3) {
                            Text("Stage \(stage.id)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(secondaryText)
                            Text(stage.label)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(primaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(stage.id == model.activeStage ? Color.white.opacity(0.16) : Color.white.opacity(0.055))
                        .glassEffect(
                            .regular.tint(stage.id == model.activeStage ? Color.white.opacity(0.09) : Color.white.opacity(0.025)).interactive(),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(stage.id == model.activeStage ? Color.white.opacity(0.20) : borderColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(panelColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .glassEffect(.regular.tint(Color.white.opacity(0.02)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor)
        }
    }

    private var sensorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sensor Tuning")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(model.sensor.sensorModel)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                Text("Profile \(model.profile == 0 ? "-" : "\(model.profile)")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(secondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Spacer()
                    Text("\(Int(model.selectedDPI.rounded())) DPI")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(primaryText)
                }

                Slider(value: $model.selectedDPI, in: 100...42000, step: 100)
                    .tint(accentColor)

                Button {
                    model.applySelectedDPI()
                } label: {
                    Label("Apply Sensitivity", systemImage: "scope")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .tint(accentColor)
                .disabled(model.isBusy)
            }
            .padding(12)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .glassEffect(.regular.tint(Color.white.opacity(0.025)).interactive(), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(borderColor)
            }

            VStack(spacing: 8) {
                HStack {
                    sensorToggle("Motion Sync", .motionSync, model.sensor.motionSync)
                    sensorToggle("Ripple Control", .rippleControl, model.sensor.rippleControl)
                }
                HStack {
                    sensorToggle("Angle Snap", .angleSnap, model.sensor.angleSnap)
                    sensorToggle("Low Latency", .trackingMode, model.sensor.trackingMode)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Lift-off Distance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Spacer()
                    Text("\(model.sensor.lod)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(primaryText)
                }

                HStack(spacing: 8) {
                    ForEach([1, 2], id: \.self) { value in
                        lodButton(value)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .glassEffect(.regular.tint(Color.white.opacity(0.025)).interactive(), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(borderColor)
            }

            Text("Sensitivity = DPI. Low Latency R6 Tracking Mode'ni yoqadi: kechikish kamayadi, batareya sarfi oshadi.")
                .font(.caption)
                .foregroundStyle(secondaryText)
                .lineLimit(2)
        }
        .padding(14)
        .background(panelColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .glassEffect(.regular.tint(Color.white.opacity(0.02)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor)
        }
    }

    private func sensorToggle(_ title: String, _ toggle: SensorToggle, _ isOn: Bool) -> some View {
        Button {
            model.setSensorToggle(toggle, enabled: !isOn)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(isOn ? "On" : "Off")
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? primaryText : secondaryText)
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .background(isOn ? Color.white.opacity(0.14) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .glassEffect(.regular.tint(isOn ? Color.white.opacity(0.08) : Color.white.opacity(0.025)).interactive(), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isOn ? Color.white.opacity(0.18) : borderColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy)
    }

    @ViewBuilder
    private func lodButton(_ value: Int) -> some View {
        let isActive = value == model.sensor.lod
        let title = value == 1 ? "Low LOD" : "High LOD"

        if isActive {
            Button(title) {
                model.setLOD(value)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .tint(accentColor)
            .disabled(model.isBusy)
        } else {
            Button(title) {
                model.setLOD(value)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .tint(accentColor)
            .disabled(model.isBusy)
        }
    }

    private var footer: some View {
        HStack {
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Text(model.status)
                .font(.caption)
                .foregroundStyle(secondaryText)
                .lineLimit(2)
            Spacer()
        }
    }
}

@main
private struct R6DPIStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
