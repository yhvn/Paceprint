import PaceprintCore
import SwiftUI

/// Settings, opened from Home: the runner's name, units, Route colors and body weight.
struct SettingsView: View {
    @AppStorage(SettingsKey.name) private var name = ""
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    @AppStorage(SettingsKey.routePalette) private var palette = RoutePalette.pace
    /// Kilograms whatever the units; 0 when not set.
    @AppStorage(SettingsKey.bodyMass) private var bodyMass = 0.0
    /// The decimal pad has no return key: Done above it puts it away.
    @FocusState private var isEditingBodyMass: Bool

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
            } header: {
                Text("Name")
            } footer: {
                Text("Home greets you by it.")
            }

            Section("Units") {
                Picker("Units", selection: $units) {
                    Text("Kilometres").tag(DistanceUnit.kilometers)
                    Text("Miles").tag(DistanceUnit.miles)
                }
                .pickerStyle(.segmented)
            }

            Section("Route colors") {
                ForEach(RoutePalette.allCases, id: \.self) { option in
                    Button {
                        palette = option
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: option.swatch, startPoint: .leading, endPoint: .trailing))
                                .frame(width: 44, height: 8)
                            Text(option.name)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            if option == palette {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.Colors.info)
                            }
                        }
                    }
                    .accessibilityAddTraits(option == palette ? .isSelected : [])
                }
            }

            Section {
                HStack {
                    Text("Body weight")
                    Spacer()
                    TextField("Not set", value: bodyMassShown, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .focused($isEditingBodyMass)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(massUnit.abbreviation)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            } footer: {
                Text("Used to estimate CAL (EST). Changing it doesn't change past runs.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditingBodyMass = false }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.inkBlack)
    }

    private var massUnit: BodyMassUnit {
        BodyMassUnit(units)
    }

    /// The body weight in kg or lb by units; nil when not set. Cleared, it's not set.
    private var bodyMassShown: Binding<Double?> {
        Binding(
            get: { bodyMass > 0 ? massUnit.value(ofKilograms: bodyMass) : nil },
            set: { bodyMass = $0.map(massUnit.kilograms).flatMap { $0 > 0 ? $0 : nil } ?? 0 }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .preferredColorScheme(.dark)
}
