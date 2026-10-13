import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct GeneralPreferencesView: View {
    @EnvironmentObject private var inputDeviceManager: InputDeviceManager
    private let labelWidth: CGFloat = 100
    @AppStorage(UserDefaultsKeys.autoPasteText) private var automaticallyPasteText = true
    @AppStorage(UserDefaultsKeys.keepTranscriptionInClipboard) private var keepTranscriptionInClipboard = false
    @AppStorage(UserDefaultsKeys.lowerSystemVolumeWhileRecording) private var lowerSystemVolumeWhileRecording = true
    @AppStorage(UserDefaultsKeys.useDarkIcon) private var useDarkIcon = false
    @AppStorage(UserDefaultsKeys.showMenuBarIcon) private var showMenuBarIcon = false

    var orderedDevices: [InputDeviceManager.DeviceRecord] {
        inputDeviceManager.preferredDeviceOrder.compactMap { deviceId in
            inputDeviceManager.availableDevices.first { $0.id == deviceId }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Shortcut:")
                    .frame(width: labelWidth, alignment: .leading)

                KeyboardShortcuts.Recorder("", name: .toggleRecording)
            }

            HStack {
                Text("Language:")
                    .frame(width: labelWidth, alignment: .leading)

                LanguageSelector()
            }

            HStack(alignment: .top) {
                Text("Microphone:")
                    .frame(width: labelWidth + 8, alignment: .leading)

                List {
                    ForEach(orderedDevices) { device in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                            VStack(alignment: .leading) {
                                Text(device.name)
                            }
                            Spacer()
                            if !device.isAvailable {
                                Image(systemName: "slash.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onMove { from, to in
                        inputDeviceManager.updateDeviceOrder(from: from, to: to)
                    }
                }
                .frame(height: 120)
                .cornerRadius(4)
                .listStyle(.plain)
                .listRowInsets(EdgeInsets())
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("").frame(width: labelWidth + 8, alignment: .leading)
                    Toggle("Paste text into active field", isOn: $automaticallyPasteText)
                }

                HStack {
                    Text("").frame(width: labelWidth + 8, alignment: .leading)
                    Toggle("Keep transcription in clipboard", isOn: $keepTranscriptionInClipboard)
                }

                HStack {
                    Text("").frame(width: labelWidth + 8, alignment: .leading)
                    Toggle("Reduce system volume while recording", isOn: $lowerSystemVolumeWhileRecording)
                }

                HStack {
                    Text("").frame(width: labelWidth + 8, alignment: .leading)
                    LaunchAtLogin.Toggle()
                }

                HStack {
                    Text("").frame(width: labelWidth + 8, alignment: .leading)
                    Toggle("Use dark icon", isOn: $useDarkIcon)
                }

                HStack {
                    Text("").frame(width: labelWidth + 8, alignment: .leading)
                    Toggle("Hide Dock icon", isOn: $showMenuBarIcon)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
