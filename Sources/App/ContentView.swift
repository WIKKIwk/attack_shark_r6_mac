import SwiftUI

struct ContentView: View {
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
        ScrollView(.vertical) {
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
                    Text("Battery \(model.sensor.batteryPercent)%  •  Profile \(model.profile == 0 ? "-" : "\(model.profile)")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(secondaryText)
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Device Performance")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                        Spacer()
                        Text("Polling \(pollingLabel(model.sensor.pollingRateCode))")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(primaryText)
                    }

                    HStack {
                        sensorToggle("Hyper Mode", .hyperMode, model.sensor.hyperMode)
                        sensorToggle("DPI Indicator", .dpiIndicator, model.sensor.dpiIndicator)
                    }

                    HStack {
                        sensorToggle("DPI X/Y Split", .dpiXY, model.sensor.dpiXY)
                        comboKeyToggle
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debounce")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Text("\(model.sensor.debounceTime) ms")
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .glassEffect(.regular.tint(Color.white.opacity(0.025)).interactive(), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(borderColor)
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach([0, 2, 4, 8], id: \.self) { value in
                            settingButton("\(value)ms", active: model.sensor.debounceTime == value) {
                                model.setDebounceTime(value)
                            }
                        }
                    }

                    HStack {
                        Text("Sleep Time")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                        Spacer()
                        Text(model.sensor.sleepTime == 0 ? "Off / Default" : "\(model.sensor.sleepTime)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(primaryText)
                    }

                    HStack(spacing: 8) {
                        ForEach([0, 60, 300, 600], id: \.self) { value in
                            settingButton(sleepLabel(value), active: model.sensor.sleepTime == value) {
                                model.setSleepTime(value)
                            }
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

                Text("Low Latency va Hyper Mode batareya sarfini oshiradi. Polling hozir read-only, mapping xavfsiz tasdiqlangandan keyin yozish qo'shiladi.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
            }
            .padding(14)
        }
        .scrollIndicators(.visible)
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

    private var comboKeyToggle: some View {
        let isOn = model.sensor.buttonCombine
        return Button {
            model.setButtonCombine(enabled: !isOn)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Combo Keys")
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
    private func settingButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        if active {
            Button(title, action: action)
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .tint(accentColor)
                .disabled(model.isBusy)
        } else {
            Button(title, action: action)
                .buttonStyle(.glass)
                .controlSize(.small)
                .tint(accentColor)
                .disabled(model.isBusy)
        }
    }

    private func pollingLabel(_ code: Int) -> String {
        switch code {
        case 1: return "1K"
        case 2: return "2K"
        case 4: return "4K"
        case 8: return "8K"
        case 128: return "Max"
        default: return "Code \(code)"
        }
    }

    private func sleepLabel(_ value: Int) -> String {
        switch value {
        case 0: return "Default"
        case 60: return "1m"
        case 300: return "5m"
        case 600: return "10m"
        default: return "\(value)"
        }
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
