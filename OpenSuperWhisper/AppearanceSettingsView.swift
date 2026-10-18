import SwiftUI

/// A circle the size of the presets that opens the system color panel. The
/// ColorPicker underneath is invisible: its own well is a wide pill.
private struct CircleColorPicker: View {
    /// nil draws the rainbow "custom" swatch.
    let color: Color?
    let isSelected: Bool
    let fallback: Color
    let onPick: (Color) -> Void

    private static let rainbow = AngularGradient(
        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center
    )

    var body: some View {
        ZStack {
            Circle()
                .fill(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(Self.rainbow))
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            ColorPicker("Custom color", selection: Binding(
                get: { color ?? fallback },
                set: onPick
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 22, height: 22)
            .clipShape(Circle())
            .opacity(0.02)
        }
        .padding(3)
        .overlay(Circle().stroke(Color.primary, lineWidth: 2).opacity(isSelected ? 1 : 0))
        .help("Custom color")
    }
}

private struct SwatchOption: Identifiable {
    let label: String
    let hex: String
    let fill: Color
    var id: String { label }
}

/// A row of preset swatches plus a custom color picker, bound to a hex string
/// where the empty string selects the "no override" preset.
private struct ColorSwatchRow: View {
    let options: [SwatchOption]
    @Binding var hex: String
    let customFallback: Color

    private var isCustom: Bool {
        !options.contains { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    hex = option.hex
                } label: {
                    Circle()
                        .fill(option.fill)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                        .padding(3)
                        .overlay(
                            Circle().stroke(Color.primary, lineWidth: 2)
                                .opacity(option.hex.caseInsensitiveCompare(hex) == .orderedSame ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
                .help(option.label)
                .accessibilityLabel(option.label)
            }
            CircleColorPicker(
                color: isCustom ? ColorHex.color(from: hex) : nil,
                isSelected: isCustom,
                fallback: customFallback,
                onPick: { hex = ColorHex.hex(from: $0) ?? hex }
            )
        }
    }
}

/// The recording-indicator card at its real size, for the live preview.
private struct IndicatorPreview: View {
    @ObservedObject var appearance: AppearanceStore

    var body: some View {
        let rect = RoundedRectangle(cornerRadius: 24)
        HStack(spacing: 8) {
            RecordingIndicator(isBlinking: false, color: appearance.indicatorDotColor)
                .frame(width: 24)
            Text("Recording...")
                .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .frame(width: IndicatorWindow.cardSize.width, height: IndicatorWindow.cardSize.height)
        .background(IndicatorCardBackground(style: appearance.indicatorBackground, appearance: appearance))
        .clipShape(rect)
        .scaleEffect(appearance.indicatorSize.scale)
        .frame(height: IndicatorWindow.cardSize.height * IndicatorSize.large.scale)
    }
}

/// Observes only the tint model, so dragging redraws this row and the window
/// background rather than the whole settings sheet.
private struct WindowTintSlider: View {
    @ObservedObject var tint: WindowTintModel

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $tint.opacity, in: AppearanceDefaults.opacityRange)
                .frame(width: 180)
            Text("\(Int((tint.opacity * 100).rounded()))%")
                .font(.subheadline)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}

struct AppearanceSettingsView: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @Environment(\.colorScheme) private var colorScheme

    private let indicatorColors = [
        SwatchOption(label: "Red", hex: "", fill: .red),
        SwatchOption(label: "Beluga blue", hex: AppearanceDefaults.beluga, fill: Color(hex: AppearanceDefaults.beluga)),
        SwatchOption(label: "Green", hex: "#34C759", fill: Color(hex: "#34C759")),
        SwatchOption(label: "Purple", hex: "#AF52DE", fill: Color(hex: "#AF52DE")),
        SwatchOption(label: "White", hex: "#FFFFFF", fill: .white),
    ]

    private let accentColors = [
        SwatchOption(label: "System", hex: "", fill: Color(nsColor: .controlAccentColor)),
        SwatchOption(label: "Beluga blue", hex: AppearanceDefaults.beluga, fill: Color(hex: AppearanceDefaults.beluga)),
        SwatchOption(label: "Green", hex: "#34C759", fill: Color(hex: "#34C759")),
        SwatchOption(label: "Purple", hex: "#AF52DE", fill: Color(hex: "#AF52DE")),
        SwatchOption(label: "Pink", hex: "#FF2D92", fill: Color(hex: "#FF2D92")),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                indicatorCard
                accentCard
                windowCard

                HStack {
                    Button("Reset to defaults") {
                        appearance.resetToDefaults()
                    }
                    Spacer()
                }
            }
            .padding()
        }
    }

    private var indicatorCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recording indicator")
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
                Spacer()
                IndicatorPreview(appearance: appearance)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(10)

            row("Color", caption: "Replaces the recording dot.") {
                ColorSwatchRow(options: indicatorColors, hex: $appearance.indicatorColorHex, customFallback: .red)
            }

            row("Size", caption: "Applies the next time the indicator appears.") {
                Picker("", selection: $appearance.indicatorSize) {
                    ForEach(IndicatorSize.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }

            row("Background") {
                Picker("", selection: $appearance.indicatorBackground) {
                    ForEach(IndicatorBackgroundStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)
            }
        }
        .cardStyle()
    }

    private var accentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accent color")
                .font(.headline)
                .foregroundColor(.primary)

            row("Accent", caption: "Buttons, toggles, links and the record button.") {
                ColorSwatchRow(options: accentColors, hex: $appearance.accentHex, customFallback: .accentColor)
            }
        }
        .cardStyle()
    }

    private var windowCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Window")
                .font(.headline)
                .foregroundColor(.primary)

            row("Background", caption: "Main window only. Settings stays opaque.") {
                Picker("", selection: $appearance.windowStyle) {
                    ForEach(WindowBackgroundStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)
            }

            if appearance.windowStyle != .system {
                row(appearance.windowStyle == .translucent ? "Tint color" : "Color",
                    caption: "Reset follows light and dark mode.") {
                    HStack(spacing: 8) {
                        CircleColorPicker(
                            color: appearance.windowBaseColor(for: colorScheme),
                            isSelected: false,
                            fallback: .clear,
                            onPick: { appearance.windowColorHex = ColorHex.hex(from: $0) ?? appearance.windowColorHex }
                        )
                        Button("Reset") { appearance.windowColorHex = "" }
                            .controlSize(.small)
                            .disabled(appearance.windowColorHex.isEmpty)
                    }
                }
            }

            if appearance.windowStyle == .translucent {
                row("Tint strength", caption: "How much of the color covers the blur. 60 to 100%.") {
                    WindowTintSlider(tint: appearance.tint)
                }
            }
        }
        .cardStyle()
    }

    private func row<Content: View>(_ title: String, caption: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            content()
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor).opacity(0.3))
            .cornerRadius(12)
    }
}

private extension Color {
    /// For fixed, known-good literals only.
    init(hex: String) {
        self = ColorHex.color(from: hex) ?? .clear
    }
}
