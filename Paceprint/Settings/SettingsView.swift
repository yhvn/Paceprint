import PaceprintCore
import SwiftUI

/// Settings, opened from Home: the runner's name, units, Route colors, Apple Health and body weight.
struct SettingsView: View {
    @Environment(RunHealthSync.self) private var healthSync
    @AppStorage(SettingsKey.saveToHealth) private var saveToHealth = false
    /// Apple Health's latest body weight in kg as last read; 0 when there's none, and the field is editable.
    @AppStorage(SettingsKey.healthBodyMass) private var healthBodyMass = 0.0
    /// Health permission was asked for and refused.
    @State private var isHealthRefused = false
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

            if healthSync.isAvailable {
                Section {
                    // A closure, not `set: setSavingToHealth`: a method reference here crashes the Swift 6.2 compiler.
                    Toggle("Save runs to Health", isOn: Binding(get: { saveToHealth }, set: { setSavingToHealth($0) }))
                } header: {
                    Text("Apple Health")
                } footer: {
                    if isHealthRefused {
                        Text("Allow Paceprint in the Health app › Sharing › Apps.")
                    } else {
                        Text("Your runs, routes and calories appear in Health.")
                    }
                }
            }

            Section {
                if healthBodyMass > 0 {
                    // Health's weight wins, so it isn't editable here.
                    LabeledContent("Body weight", value: "\(weightText(massUnit.value(ofKilograms: healthBodyMass))) · from Apple Health")
                } else {
                    bodyMassField
                }
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
        .task {
            isHealthRefused = healthSync.isRefused
            await healthSync.refreshBodyMass()
        }
    }

    /// Turning it on asks for Health permission the first time, and stays off if saving isn't allowed.
    private func setSavingToHealth(_ isOn: Bool) {
        guard isOn else {
            healthSync.turnOff()
            return
        }
        Task {
            isHealthRefused = !(await healthSync.connect())
        }
    }

    private var bodyMassField: some View {
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
        .accessibilityValue(bodyMassShown.wrappedValue.map(weightText) ?? "Not set")
    }

    private var massUnit: BodyMassUnit {
        units.bodyMassUnit
    }

    /// A body weight in kg or lb by units, e.g. "154 lb" or "72.4 kg".
    private func weightText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(massUnit.abbreviation)"
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

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(RunHealthSync.preview)
    .preferredColorScheme(.dark)
}
#endif
