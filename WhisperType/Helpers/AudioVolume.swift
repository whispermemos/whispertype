//
//  AudioVolume.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 02/01/2025.
//

import CoreAudio

final class SystemAudioVolumeController {
    private var snapshot: SystemAudioVolumeSnapshot?

    func lowerSystemVolumeForRecording(targetVolume: Float32 = 0.3) {
        guard snapshot == nil else { return }
        guard let deviceID = defaultOutputDeviceID() else { return }
        guard let snapshot = captureSnapshot(for: deviceID) else { return }

        self.snapshot = snapshot
        applyLoweredVolume(snapshot: snapshot, targetVolume: targetVolume)
    }

    func restoreSystemVolume() {
        guard let snapshot else { return }
        applySnapshot(snapshot)
        self.snapshot = nil
    }
}

private struct SystemAudioVolumeSnapshot {
    let deviceID: AudioObjectID
    let volumeMode: VolumeMode
    let volumeSnapshots: [AudioPropertySnapshot<Float32>]
    let muteSnapshots: [AudioPropertySnapshot<UInt32>]
}

private enum VolumeMode {
    case master
    case perChannel
}

private struct AudioPropertySnapshot<Value> {
    let address: AudioObjectPropertyAddress
    let value: Value
}

private func applyLoweredVolume(snapshot: SystemAudioVolumeSnapshot, targetVolume: Float32) {
    let clampedTarget = max(0, min(1, targetVolume))

    switch snapshot.volumeMode {
    case .master:
        guard let current = snapshot.volumeSnapshots.first else { return }
        let newValue = min(current.value, clampedTarget)
        _ = setFloat32Property(
            deviceID: snapshot.deviceID,
            address: current.address,
            value: newValue
        )
    case .perChannel:
        let currentValues = snapshot.volumeSnapshots.map(\.value)
        let maxValue = currentValues.max() ?? 0
        let scale = maxValue > 0 ? min(1, clampedTarget / maxValue) : 0

        for volumeSnapshot in snapshot.volumeSnapshots {
            let newValue = volumeSnapshot.value * scale
            _ = setFloat32Property(
                deviceID: snapshot.deviceID,
                address: volumeSnapshot.address,
                value: newValue
            )
        }
    }

    applyMuteSnapshots(snapshot)
}

private func applySnapshot(_ snapshot: SystemAudioVolumeSnapshot) {
    for volumeSnapshot in snapshot.volumeSnapshots {
        _ = setFloat32Property(
            deviceID: snapshot.deviceID,
            address: volumeSnapshot.address,
            value: volumeSnapshot.value
        )
    }

    applyMuteSnapshots(snapshot)
}

private func applyMuteSnapshots(_ snapshot: SystemAudioVolumeSnapshot) {
    for muteSnapshot in snapshot.muteSnapshots {
        _ = setUInt32Property(
            deviceID: snapshot.deviceID,
            address: muteSnapshot.address,
            value: muteSnapshot.value
        )
    }
}

private func captureSnapshot(for deviceID: AudioObjectID) -> SystemAudioVolumeSnapshot? {
    guard let (volumeMode, volumeAddresses) = volumeAddresses(for: deviceID) else {
        return nil
    }

    let volumeSnapshots = volumeAddresses.compactMap { address -> AudioPropertySnapshot<Float32>? in
        guard let value = readFloat32Property(deviceID: deviceID, address: address) else { return nil }
        return AudioPropertySnapshot(address: address, value: value)
    }

    guard !volumeSnapshots.isEmpty else { return nil }

    let muteAddresses = muteAddresses(
        deviceID: deviceID,
        volumeMode: volumeMode,
        volumeSnapshots: volumeSnapshots
    )

    let muteSnapshots = muteAddresses.compactMap { address -> AudioPropertySnapshot<UInt32>? in
        guard let value = readUInt32Property(deviceID: deviceID, address: address) else { return nil }
        return AudioPropertySnapshot(address: address, value: value)
    }

    return SystemAudioVolumeSnapshot(
        deviceID: deviceID,
        volumeMode: volumeMode,
        volumeSnapshots: volumeSnapshots,
        muteSnapshots: muteSnapshots
    )
}

private func volumeAddresses(
    for deviceID: AudioObjectID
) -> (VolumeMode, [AudioObjectPropertyAddress])? {
    let masterAddress = makeAddress(
        selector: kAudioDevicePropertyVolumeScalar,
        scope: kAudioDevicePropertyScopeOutput,
        element: kAudioObjectPropertyElementMaster
    )

    if canSetProperty(deviceID: deviceID, address: masterAddress) {
        return (.master, [masterAddress])
    }

    let channelCount = outputChannelCount(for: deviceID)
    guard channelCount > 0 else { return nil }

    var channelAddresses: [AudioObjectPropertyAddress] = []
    for channel in 1...channelCount {
        let address = makeAddress(
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: channel
        )
        if canSetProperty(deviceID: deviceID, address: address) {
            channelAddresses.append(address)
        }
    }

    guard !channelAddresses.isEmpty else { return nil }
    return (.perChannel, channelAddresses)
}

private func muteAddresses(
    deviceID: AudioObjectID,
    volumeMode: VolumeMode,
    volumeSnapshots: [AudioPropertySnapshot<Float32>]
) -> [AudioObjectPropertyAddress] {
    let elements: [AudioObjectPropertyElement]

    switch volumeMode {
    case .master:
        elements = [kAudioObjectPropertyElementMaster]
    case .perChannel:
        elements = volumeSnapshots.map { $0.address.mElement }
    }

    var addresses: [AudioObjectPropertyAddress] = []
    for element in elements {
        let address = makeAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            element: element
        )
        if canSetProperty(deviceID: deviceID, address: address) {
            addresses.append(address)
        }
    }

    return addresses
}

private func outputChannelCount(for deviceID: AudioObjectID) -> AudioObjectPropertyElement {
    var address = makeAddress(
        selector: kAudioDevicePropertyStreamConfiguration,
        scope: kAudioDevicePropertyScopeOutput,
        element: kAudioObjectPropertyElementMaster
    )

    var dataSize: UInt32 = 0
    let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
    guard sizeStatus == noErr, dataSize > 0 else { return 0 }

    let bufferListPointer = UnsafeMutableRawPointer.allocate(
        byteCount: Int(dataSize),
        alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { bufferListPointer.deallocate() }

    let audioBufferList = bufferListPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
    var propertySize = dataSize
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, audioBufferList)
    guard status == noErr else { return 0 }

    let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
    let channelCount = bufferList.reduce(UInt32(0)) { $0 + $1.mNumberChannels }
    return channelCount
}

private func defaultOutputDeviceID() -> AudioObjectID? {
    var address = makeAddress(
        selector: kAudioHardwarePropertyDefaultOutputDevice,
        scope: kAudioObjectPropertyScopeGlobal,
        element: kAudioObjectPropertyElementMaster
    )

    var deviceID = AudioObjectID(0)
    var dataSize = UInt32(MemoryLayout.size(ofValue: deviceID))
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &dataSize,
        &deviceID
    )

    return status == noErr ? deviceID : nil
}

private func canSetProperty(deviceID: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
    var address = address
    guard AudioObjectHasProperty(deviceID, &address) else { return false }

    var isSettable: DarwinBoolean = false
    let status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
    return status == noErr && isSettable.boolValue
}

private func readFloat32Property(
    deviceID: AudioObjectID,
    address: AudioObjectPropertyAddress
) -> Float32? {
    var address = address
    var value: Float32 = 0
    var size = UInt32(MemoryLayout.size(ofValue: value))
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
    return status == noErr ? value : nil
}

private func readUInt32Property(
    deviceID: AudioObjectID,
    address: AudioObjectPropertyAddress
) -> UInt32? {
    var address = address
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout.size(ofValue: value))
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
    return status == noErr ? value : nil
}

private func setFloat32Property(
    deviceID: AudioObjectID,
    address: AudioObjectPropertyAddress,
    value: Float32
) -> Bool {
    var address = address
    var value = value
    let size = UInt32(MemoryLayout.size(ofValue: value))
    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
    return status == noErr
}

private func setUInt32Property(
    deviceID: AudioObjectID,
    address: AudioObjectPropertyAddress,
    value: UInt32
) -> Bool {
    var address = address
    var value = value
    let size = UInt32(MemoryLayout.size(ofValue: value))
    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
    return status == noErr
}

private func makeAddress(
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope,
    element: AudioObjectPropertyElement
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: element
    )
}
