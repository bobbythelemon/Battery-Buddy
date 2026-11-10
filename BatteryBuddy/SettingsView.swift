import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: BatteryViewModel

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

            Section("Energy") {
                Toggle("Show top 3 CPU usage apps", isOn: $viewModel.showTopEnergyApps)
            }
        }
        .padding()
        .frame(width: 420, height: 300)
    }
}
