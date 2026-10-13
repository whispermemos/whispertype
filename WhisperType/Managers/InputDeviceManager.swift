import Foundation
import AVFoundation
import SimplyCoreAudio

class InputDeviceManager: ObservableObject {
    private let simplyCA: SimplyCoreAudio
    
    @Published private(set) var availableDevices: [DeviceRecord] = []
    @Published var preferredDeviceOrder: [String] = []
    
    private let userDefaults = UserDefaults.standard
    private let knownDevicesKey = "InputDeviceManager.knownDevices"
    private let preferredOrderKey = "InputDeviceManager.preferredOrder"
    
    struct DeviceRecord: Identifiable, Codable, Equatable {
        let uid: String
        let name: String
        var isAvailable: Bool
        
        static func == (lhs: DeviceRecord, rhs: DeviceRecord) -> Bool {
            lhs.uid == rhs.uid && lhs.isAvailable == rhs.isAvailable
        }
        
        var id: String { uid }
    }
    
    init(simplyCA: SimplyCoreAudio) {
        self.simplyCA = simplyCA
        
        loadKnownDevices()
        startDeviceMonitoring()
    }
    
    private func loadKnownDevices() {
        // Load preferred order
        preferredDeviceOrder = userDefaults.stringArray(forKey: preferredOrderKey) ?? []
        
        // Load known devices
        if let data = userDefaults.data(forKey: knownDevicesKey),
           let devices = try? JSONDecoder().decode([DeviceRecord].self, from: data) {
            availableDevices = devices
        }
        
        // Update with currently available devices
        updateAvailableDevices()
    }
    
    private func updateAvailableDevices() {
        let currentDevices = simplyCA.allInputDevices.filter {
            // skip aggregate devices
            !$0.isAggregateDevice &&
            // skip continuity on iPhone
            !($0.manufacturer == "Apple Inc." && $0.modelUID == "iPhone Mic")
        }
        
        // Create set of current device IDs
        let currentDeviceIds = Set(currentDevices.map { $0.uid })
        
        // Update availability of known devices
        var updatedDevices = availableDevices
        
        for i in 0..<updatedDevices.count {
            let isAvailable = currentDeviceIds.contains(updatedDevices[i].uid)
            updatedDevices[i].isAvailable = isAvailable
        }
        
        // Add new devices
        for device in currentDevices {
            if let uid = device.uid, !updatedDevices.contains(where: { $0.uid == device.uid }) {
                let newDevice = DeviceRecord(
                    uid: uid,
                    name: device.name,
                    isAvailable: true
                )
                updatedDevices.append(newDevice)
                
                // Add to preferred order if not present
                if !preferredDeviceOrder.contains(uid) {
                    preferredDeviceOrder.append(uid)
                }
            }
        }
        
        availableDevices = updatedDevices
        objectWillChange.send()
        
//        print("updated available devices: \(updatedDevices)")
        
        saveDevices()
    }
    
    private func saveDevices() {
        if let encoded = try? JSONEncoder().encode(availableDevices) {
            userDefaults.set(encoded, forKey: knownDevicesKey)
        }
        userDefaults.set(preferredDeviceOrder, forKey: preferredOrderKey)
    }
    
    func updateDeviceOrder(from: IndexSet, to: Int) {
        preferredDeviceOrder.move(fromOffsets: from, toOffset: to)
        saveDevices()
    }
    
    private func startDeviceMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceChange),
            name: .deviceListChanged,
            object: nil
        )
    }
    
    @objc private func handleDeviceChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateAvailableDevices()
        }
    }
    
    func getPreferredDevice() -> AudioDevice? {
        // Get first available device from preferred order
        for uid in preferredDeviceOrder {
            if let device = availableDevices.first(where: { $0.uid == uid && $0.isAvailable }),
            let simpleDevice = simplyCA.allInputDevices.first(where: { $0.uid == device.uid }) {
                return simpleDevice
            }
        }
        
        // Fallback to default device if no preferred device is available
        return simplyCA.defaultInputDevice
    }
}
