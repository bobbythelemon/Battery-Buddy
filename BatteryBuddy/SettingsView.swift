import SwiftUI
import Sparkle

struct SettingsView: View {
    @ObservedObject var viewModel: BatteryViewModel
    let updaterController: SPUStandardUpdaterController

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show battery percentage", isOn: $viewModel.showPercentageInMenuBar)
                Toggle("Percentage text is white", isOn: $viewModel.percentageTextIsWhite)
                Toggle("Use white normal-mode icon", isOn: $viewModel.useWhiteNormalIcon)
            }

            Section("Dropdown Display") {
                Toggle("Show battery health", isOn: $viewModel.showHealthInPopover)
                Toggle("Show status", isOn: $viewModel.showStatusInPopover)
                Toggle("Show cycles", isOn: $viewModel.showCyclesInPopover)
                Toggle("Show wattage", isOn: $viewModel.showWattageInPopover)
            }

            Section("Updates") {
                Button("Check for Updates Now") {
                    updaterController.checkForUpdates(nil)
                }

                Text("BatteryBuddy checks GitHub Releases automatically using Sparkle 2.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 420, height: 300)
    }
}
