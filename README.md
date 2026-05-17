# R6 DPI Studio

Native macOS controller for the **ATTACK SHARK R6** mouse.

R6 DPI Studio is a lightweight SwiftUI app that talks to the mouse directly over HID, so the real onboard mouse settings are changed instead of only speeding up the macOS pointer.

## Highlights

- Native macOS app with a compact dark interface.
- Real onboard DPI control for ATTACK SHARK R6.
- DPI stage reading, activation, and custom DPI writing.
- Sensor tuning controls for supported safe settings.
- Battery, firmware, profile, and active stage status.
- 2.4G dongle and USB-C support.
- No Windows VM required for normal DPI and sensor tuning.

## Supported Device

| Device | VID | PID | Connection |
| --- | --- | --- | --- |
| ATTACK SHARK R6 | `0x373e` | `0x0022` | 2.4G dongle or USB-C |

Bluetooth is not supported because the device configuration protocol is exposed through the HID interface used by the dongle or wired mode.

## Features

### DPI

- Read onboard DPI stages.
- Switch active DPI stage.
- Write custom DPI values.
- Presets: `800`, `1200`, `1600`, `2000`, `2400`, `2800`, `3200`, `5600`, `8000`.
- Custom range: `100` to `42000` DPI.

### Sensor

- Motion Sync
- Ripple Control
- Angle Snap
- Low Latency / Tracking Mode
- Lift-off Distance
- Hyper Mode
- DPI Indicator
- DPI X/Y Split
- Combo Keys
- Debounce Time
- Sleep Time

Polling rate is currently read-only until the R6 mapping is verified safely.

## Safety Scope

This app intentionally avoids risky commands that can break the mouse or receiver pairing:

- Firmware update / bootloader mode
- Receiver binding
- Factory reset
- Macro memory writing
- Button remapping
- Unverified polling-rate writes

## Requirements

- macOS 14 or newer
- Swift toolchain / Xcode Command Line Tools
- ATTACK SHARK R6 connected through 2.4G dongle or USB-C

Install command line tools if needed:

```sh
xcode-select --install
```

## Build

```sh
git clone https://github.com/WIKKIwk/attack_shark_r6_mac.git
cd attack_shark_r6_mac
./build.sh
```

The app bundle is generated here:

```sh
build/R6 DPI Studio.app
```

## Package DMG

```sh
./build.sh
./package-dmg.sh
```

The DMG installer is generated here:

```sh
build/R6-DPI-Studio.dmg
```

## Run

```sh
open "build/R6 DPI Studio.app"
```

To keep it on Desktop:

```sh
cp -R "build/R6 DPI Studio.app" "$HOME/Desktop/R6 DPI Studio.app"
open "$HOME/Desktop/R6 DPI Studio.app"
```

## Project Structure

```text
.
|-- Sources/
|   `-- R6DPIApp.swift
|-- Resources/
|   |-- R6DPI.icns
|   `-- R6DPI.iconset/
|-- Info.plist
|-- build.sh
|-- package-dmg.sh
`-- README.md
```

## Notes

R6 DPI Studio changes settings through the mouse HID protocol. If the app shows `Disconnected`, reconnect the 2.4G dongle or plug the mouse in with USB-C, then press `Reconnect`.
