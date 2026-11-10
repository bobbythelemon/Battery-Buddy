import AppKit
import SwiftUI
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = BatteryViewModel()
    let updaterController: SPUStandardUpdaterController

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var observers: [NSObjectProtocol] = []

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: BatteryPopoverView(viewModel: viewModel)
        )

        viewModel.onUpdate = { [weak self] in
            self?.updateStatusItem()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageLeading

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAndUpdate()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAndUpdate()
                }
            }
        )

        refreshAndUpdate()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func refreshAndUpdate() {
        viewModel.refresh()
        updateStatusItem()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let info = viewModel.info
        let tint = info?.tintColor ?? .white
        let percentage = info?.chargePercent ?? 0
        let charging = info?.isCharging ?? false

        button.image = makeBatteryImage(
            percentage: percentage,
            tint: tint,
            charging: charging
        )

        let title = viewModel.showPercentageInMenuBar ? " \(percentage)%" : ""
        let textColor: NSColor = viewModel.percentageTextIsWhite ? .white : .black

        let attributed = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: textColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )

        button.title = ""
        button.attributedTitle = attributed
        button.toolTip = "Battery \(percentage)%"

        button.sizeToFit()

        if let frame = button.superview?.frame {
            button.superview?.frame = NSRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: max(frame.width, 75),
                height: frame.height
            )
        }
    }

    private func makeBatteryImage(percentage: Int, tint: NSColor, charging: Bool) -> NSImage {
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

    private func drawWhiteBolt(in rect: NSRect) {
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
