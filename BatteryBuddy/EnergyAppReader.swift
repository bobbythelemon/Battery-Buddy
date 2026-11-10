import Foundation

struct EnergyAppEntry: Identifiable {
    let id = UUID()
    let name: String
    let cpuPercent: Double
}

enum EnergyAppReader {
    static func readTopApps(limit: Int = 3) -> [EnergyAppEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "ps -axo comm=,pcpu="]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        var totals: [String: Double] = [:]

        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            let parts = line
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)

            guard let cpuString = parts.last else { continue }

            let command = parts.dropLast().joined(separator: " ")
            if command.isEmpty { continue }

            let baseName = URL(fileURLWithPath: command).lastPathComponent
            let displayName = baseName.isEmpty ? command : baseName

            let cpu = Double(cpuString) ?? 0
            totals[displayName, default: 0] += cpu
        }

        return totals
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { EnergyAppEntry(name: $0.key, cpuPercent: $0.value) }
    }
}
