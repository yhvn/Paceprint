import PaceprintCore
import SwiftUI

/// Settings, opened from Home: the runner's name, units, Route colors and body weight.
struct SettingsView: View {
    @AppStorage(SettingsKey.name) private var name = ""
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    @AppStorage(SettingsKey.routePalette) private var palette = RoutePalette.pace
    /// Kilograms whatever the units; 0 when not set.
    @AppStorage(SettingsKey.bodyMass) private var bodyMass = 0.0
    /// The field being typed in; Done above the keyboard puts it away (the decimal pad has no return key).
    @FocusState private var focus: Field?

    private enum Field {
        case name, bodyMass
    }

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .focused($focus, equals: .name)
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
                        .focused($focus, equals: .bodyMass)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(massUnit.abbreviation)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Body weight")
                .accessibilityValue(bodyMassShown.wrappedValue.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(massUnit.abbreviation)" } ?? "Not set")
            } footer: {
                Text("Used to estimate CAL (EST). Changing it doesn't change past runs.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.inkBlack)
    }

    private var massUnit: BodyMassUnit {
        units.bodyMassUnit
    }

    /// The body weight in kg or lb by units; nil when not set. Cleared or 0, it's not set; a weight
    /// no runner could have is ignored.
    private var bodyMassShown: Binding<Double?> {
        Binding(
            get: { bodyMass > 0 ? massUnit.value(ofKilograms: bodyMass) : nil },
            set: { value in
                guard let value, value > 0 else {
                    bodyMass = 0
                    return
                }
                let kilograms = massUnit.kilograms(value)
                if BodyMassUnit.isPlausible(kilograms: kilograms) {
                    bodyMass = kilograms
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .preferredColorScheme(.dark)
}
