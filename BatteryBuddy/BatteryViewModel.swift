import Foundation
import AppKit
import IOKit
import IOKit.ps
import Darwin

@MainActor
final class BatteryViewModel: ObservableObject {
    @Published var info: BatteryInfo?
    @Published var topEnergyApps: [EnergyAppEntry] = []

    @Published var showPercentageInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showPercentageInMenuBar, forKey: Self.showPercentageKey) }
    }

    @Published var showHealthInPopover: Bool {
        didSet { UserDefaults.standard.set(showHealthInPopover, forKey: Self.showHealthKey) }
    }

    @Published var showStatusInPopover: Bool {
        didSet { UserDefaults.standard.set(showStatusInPopover, forKey: Self.showStatusKey) }
    }

    @Published var showCyclesInPopover: Bool {
        didSet { UserDefaults.standard.set(showCyclesInPopover, forKey: Self.showCyclesKey) }
    }

    @Published var showWattageInPopover: Bool {
        didSet { UserDefaults.standard.set(showWattageInPopover, forKey: Self.showWattageKey) }
    }

    @Published var percentageTextIsWhite: Bool {
        didSet {
            UserDefaults.standard.set(percentageTextIsWhite, forKey: Self.percentageTextColourKey)
            onUpdate?()
        }
    }

    @Published var useWhiteNormalIcon: Bool {
        didSet { UserDefaults.standard.set(useWhiteNormalIcon, forKey: Self.whiteNormalIconKey) }
    }

    @Published var showTopEnergyApps: Bool {
        didSet { UserDefaults.standard.set(showTopEnergyApps, forKey: Self.showTopEnergyAppsKey) }
    }

    var onUpdate: (() -> Void)?
    private var timer: Timer?

    private static let showPercentageKey = "showPercentageInMenuBar"
    private static let showHealthKey = "showHealthInPopover"
    private static let showStatusKey = "showStatusInPopover"
    private static let showCyclesKey = "showCyclesInPopover"
    private static let showWattageKey = "showWattageInPopover"
    private static let percentageTextColourKey = "percentageTextIsWhite"
    private static let whiteNormalIconKey = "useWhiteNormalIcon"
    private static let showTopEnergyAppsKey = "showTopEnergyApps"

    init() {
        showPercentageInMenuBar = UserDefaults.standard.object(forKey: Self.showPercentageKey) as? Bool ?? true
        showHealthInPopover = UserDefaults.standard.object(forKey: Self.showHealthKey) as? Bool ?? true
        showStatusInPopover = UserDefaults.standard.object(forKey: Self.showStatusKey) as? Bool ?? true
        showCyclesInPopover = UserDefaults.standard.object(forKey: Self.showCyclesKey) as? Bool ?? true
        showWattageInPopover = UserDefaults.standard.object(forKey: Self.showWattageKey) as? Bool ?? true
        percentageTextIsWhite = UserDefaults.standard.object(forKey: Self.percentageTextColourKey) as? Bool ?? false
        useWhiteNormalIcon = UserDefaults.standard.object(forKey: Self.whiteNormalIconKey) as? Bool ?? false
        showTopEnergyApps = UserDefaults.standard.object(forKey: Self.showTopEnergyAppsKey) as? Bool ?? true

        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        info = BatteryInfo.read()
        topEnergyApps = showTopEnergyApps ? EnergyAppReader.readTopApps(limit: 3) : []
        onUpdate?()
    }
}

struct BatteryInfo {
    let currentCapacity: Int
    let maxCapacity: Int
    let designCapacity: Int?
    let cycleCount: Int?
    let isCharging: Bool
    let isLowPowerMode: Bool
    let powerSourceState: String
    let condition: String?
    let dischargeWatts: Double?
    let appleSiliconHealthPercent: Int?
    let estimatedTimeRemainingMinutes: Int?
    let estimatedTimeToFullChargeMinutes: Int?

    var chargePercent: Int {
        guard maxCapacity > 0 else { return 0 }
        return Int(round((Double(currentCapacity) / Double(maxCapacity)) * 100))
    }

    var healthPercent: Int? {
        if let appleSiliconHealthPercent {
            return appleSiliconHealthPercent
        }

        guard let designCapacity, designCapacity > 0, maxCapacity > 0 else { return nil }
        return Int(round((Double(maxCapacity) / Double(designCapacity)) * 100))
    }

    var healthCategory: String {
        if let healthPercent {
            switch healthPercent {
            case 90...:
                return "Excellent"
            case 80..<90:
                return "Great"
            case 70..<80:
                return "Good"
            case 55..<70:
                return "Okay"
            case 40..<55:
                return "Weak"
            default:
                return "Poor"
            }
        }

        if let condition, !condition.isEmpty {
            return condition
        }

        return "Not available"
    }

    var healthIcon: String {
        if let healthPercent {
            switch healthPercent {
            case 90...:
                return "🌟"
            case 80..<90:
                return "⚡"
            case 70..<80:
                return "🙂"
            case 55..<70:
                return "🟡"
            case 40..<55:
                return "😟"
            default:
                return "🪫"
            }
        }

        return "❓"
    }

    var tintColor: NSColor {
        if isCharging {
            return .systemGreen
        }
        if chargePercent < 20 {
            return .systemRed
        }
        if isLowPowerMode {
            return .systemYellow
        }
        return .white
    }

    var statusText: String {
        if isCharging { return "Charging" }
        if isLowPowerMode { return "Low Power Mode" }
        return "Discharging"
    }

    var wattageText: String {
        if isCharging { return "—" }
        if let dischargeWatts {
            return String(format: "%.1f W", dischargeWatts)
        }
        return "—"
    }

    var batteryHealthText: String {
        if let healthPercent {
            return "\(healthPercent)%"
        }
        if let condition, !condition.isEmpty {
            return condition
        }
        return "Not available"
    }

    var estimatedTimeText: String {
        if isCharging {
            if let estimatedTimeToFullChargeMinutes {
                return Self.formatMinutes(estimatedTimeToFullChargeMinutes) + " to full"
            }
            return "n/a"
        } else {
            if let estimatedTimeRemainingMinutes {
                return Self.formatMinutes(estimatedTimeRemainingMinutes) + " remaining"
            }
            return "n/a"
        }
    }

    private static func formatMinutes(_ minutes: Int) -> String {
        let safe = max(0, minutes)
        let hours = safe / 60
        let mins = safe % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    static func read() -> BatteryInfo? {
        guard let sourceInfoUnmanaged = IOPSCopyPowerSourcesInfo() else { return nil }
        let sourceInfo = sourceInfoUnmanaged.takeRetainedValue()

        guard let sourceListUnmanaged = IOPSCopyPowerSourcesList(sourceInfo) else { return nil }
        let sources = sourceListUnmanaged.takeRetainedValue() as [CFTypeRef]

        guard let source = sources.first,
              let descriptionUnmanaged = IOPSGetPowerSourceDescription(sourceInfo, source) else {
            return nil
        }

        let desc = descriptionUnmanaged.takeUnretainedValue() as NSDictionary
        let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacityFromPowerSource = desc[kIOPSMaxCapacityKey] as? Int
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let powerSourceState = desc[kIOPSPowerSourceStateKey] as? String ?? "Unknown"

        let estimatedTimeRemainingMinutes = desc[kIOPSTimeToEmptyKey] as? Int
        let estimatedTimeToFullChargeMinutes = desc[kIOPSTimeToFullChargeKey] as? Int

        let registry = readBatteryRegistryValues()
        let systemInfo = isAppleSilicon ? readAppleSiliconSystemInfo() : nil

        let maxCapacity = maxCapacityFromPowerSource ?? registry.maxCapacity ?? 0
        let designCapacity = isAppleSilicon ? nil : registry.designCapacity
        let cycleCount = registry.cycleCount
        let condition = systemInfo?.condition ?? registry.conditionText
        let dischargeWatts = registry.dischargeWatts
        let appleSiliconHealthPercent = systemInfo?.maximumCapacityPercent

        return BatteryInfo(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity,
            cycleCount: cycleCount,
            isCharging: isCharging,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            powerSourceState: powerSourceState,
            condition: condition,
            dischargeWatts: dischargeWatts,
            appleSiliconHealthPercent: appleSiliconHealthPercent,
            estimatedTimeRemainingMinutes: estimatedTimeRemainingMinutes,
            estimatedTimeToFullChargeMinutes: estimatedTimeToFullChargeMinutes
        )
    }

    private static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return value == 1
    }

    private static func readAppleSiliconSystemInfo() -> (maximumCapacityPercent: Int?, condition: String?)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType", "-detailLevel", "mini"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return nil
        }

        var maximumCapacity: Int?
        var condition: String?

        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("Maximum Capacity:") {
                maximumCapacity = extractInt(from: line)
            } else if line.hasPrefix("Condition:") {
                condition = line.replacingOccurrences(of: "Condition:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        return (maximumCapacity, condition)
    }

    private static func extractInt(from line: String) -> Int? {
        Int(line.filter { "0123456789".contains($0) })
    }

    private struct RegistryValues {
        var designCapacity: Int?
        var maxCapacity: Int?
        var cycleCount: Int?
        var conditionText: String?
        var dischargeWatts: Double?
    }

    private static func readBatteryRegistryValues() -> RegistryValues {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return RegistryValues() }
        defer { IOObjectRelease(iterator) }

        var values = RegistryValues()

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            var props: Unmanaged<CFMutableDictionary>?
            let status = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)

            guard status == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            if values.designCapacity == nil, let v = dict["DesignCapacity"] as? NSNumber {
                values.designCapacity = v.intValue
            }

            if values.maxCapacity == nil {
                if let v = dict["MaxCapacity"] as? NSNumber {
                    values.maxCapacity = v.intValue
                } else if let v = dict["Maximum Capacity"] as? NSNumber {
                    values.maxCapacity = v.intValue
                }
            }

            if values.cycleCount == nil, let v = dict["CycleCount"] as? NSNumber {
                values.cycleCount = v.intValue
            }

            if values.conditionText == nil, let v = dict["BatteryHealth"] as? String {
                values.conditionText = v
            }

            if values.dischargeWatts == nil {
                let amperage = (dict["InstantAmperage"] as? NSNumber)?.doubleValue
                    ?? (dict["Amperage"] as? NSNumber)?.doubleValue
                let voltage = (dict["Voltage"] as? NSNumber)?.doubleValue

                if let amperage, let voltage {
                    values.dischargeWatts = abs(amperage * voltage) / 1_000_000.0
                }
            }
        }

        return values
    }
}
