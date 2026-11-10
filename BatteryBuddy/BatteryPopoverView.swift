import SwiftUI
import AppKit

struct BatteryPopoverView: View {
    @ObservedObject var viewModel: BatteryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let info = viewModel.info {
                batteryCard(info)
                statusCard(info)

                if viewModel.showTopEnergyApps {
                    energyAppsCard
                }
            } else {
                Text("No battery data found.")
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(width: 420)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: Self.makeBatteryImage(
                percentage: viewModel.info?.chargePercent ?? 0,
                tint: viewModel.info?.tintColor ?? .white,
                charging: viewModel.info?.isCharging ?? false
            ))
            .resizable()
            .scaledToFit()
            .frame(width: 52, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Battery")
                    .font(.title2)
                    .bold()

                Text(viewModel.info?.healthCategory ?? "Unknown")
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Refresh stats")

            if #available(macOS 14.0, *) {
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Open Settings")
            } else {
                // Fallback on earlier versions
            }
        }
        .padding(.bottom, 4)
    }

    private func batteryCard(_ info: BatteryInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Charge")
                    .font(.headline)
                Spacer()
                Text("\(info.chargePercent)%")
                    .font(.headline)
            }

            ProgressView(value: Double(info.chargePercent) / 100.0)
                .tint(.accentColor)

            if viewModel.showHealthInPopover {
                HStack {
                    Text("Battery Health")
                        .font(.headline)
                    Spacer()
                    Text(info.batteryHealthText)
                        .font(.headline)
                }

                HStack {
                    Text("Health Status")
                    Spacer()
                    Text(info.healthCategory)
                }
            }

            if viewModel.showCyclesInPopover {
                HStack {
                    Text("Cycles")
                    Spacer()
                    Text(info.cycleCount.map(String.init) ?? "—")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusCard(_ info: BatteryInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            if viewModel.showStatusInPopover {
                HStack {
                    Text("Power")
                    Spacer()
                    Text(info.isCharging ? "Charging" : "Not Charging")
                }

                HStack {
                    Text("State")
                    Spacer()
                    Text(info.statusText)
                }
            }

            HStack {
                Text("Estimated time")
                Spacer()
                Text(info.estimatedTimeText)
            }

            if viewModel.showWattageInPopover {
                HStack {
                    Text("Wattage")
                    Spacer()
                    Text(info.wattageText)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var energyAppsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top energy use (estimated)")
                .font(.headline)

            if viewModel.topEnergyApps.isEmpty {
                Text("n/a")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.topEnergyApps) { app in
                    HStack {
                        Text(app.name)
                        Spacer()
                        Text(String(format: "%.1f%% CPU", app.cpuPercent))
                            .foregroundColor(.secondary)
                    }
                }

                Text("Estimate based on current CPU usage.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private static func makeBatteryImage(percentage: Int, tint: NSColor, charging: Bool) -> NSImage {
        let size = NSSize(width: 24, height: 14)
        let image = NSImage(size: size)

        image.lockFocus()

        let bodyRect = NSRect(x: 0.8, y: 1.6, width: 20.2, height: 10.8)
        let terminalRect = NSRect(x: 21.2, y: 4.4, width: 2.0, height: 5.2)

        tint.setStroke()
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 3.4, yRadius: 3.4)
        bodyPath.lineWidth = 1.4
        bodyPath.stroke()

        let innerPadding: CGFloat = 1.3
        let innerWidth = bodyRect.width - (innerPadding * 2)
        let fillWidth = max(0, min(innerWidth, innerWidth * CGFloat(percentage) / 100.0))

        if fillWidth > 0 {
            let fillRect = NSRect(
                x: bodyRect.minX + innerPadding,
                y: bodyRect.minY + innerPadding,
                width: fillWidth,
                height: bodyRect.height - (innerPadding * 2)
            )
            tint.setFill()
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.4, yRadius: 2.4)
            fillPath.fill()
        }

        tint.setFill()
        let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 1, yRadius: 1)
        terminalPath.fill()

        if charging {
            drawWhiteBolt(in: NSRect(x: 6.4, y: 1.2, width: 10.4, height: 10.4))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawWhiteBolt(in rect: NSRect) {
        NSColor.white.setFill()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + rect.width * 0.52, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.54))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.54))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.38, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.46))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.46))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.74, y: rect.maxY))
        path.close()

        path.fill()
    }
}
