import SwiftUI

/// The Settings sidebar: one row per section, the selected row filled with the accent.
/// The title bar is transparent and the content runs under it, so the safe area (plus a little padding)
/// clears the traffic lights.
struct SettingsSidebar: View {
    @Binding var selection: SettingsSection
    @ObservedObject private var appearance = AppearanceStore.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let surfaces = appearance.surfaces(for: colorScheme)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { section in
                row(section, textColor: Color(hex: surfaces.text))
            }

            Spacer(minLength: 12)

            Link(destination: URL(string: "https://github.com/Starmel/OpenSuperWhisper")!) {
                HStack(spacing: 4) {
                    Image(systemName: "star")
                        .font(.system(size: 10))
                    Text("GitHub")
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(hex: surfaces.secondaryText))
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: SettingsWindowMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
        .background(Color(hex: surfaces.sidebar).ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(hex: surfaces.border))
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }

    private func row(_ section: SettingsSection, textColor: Color) -> some View {
        let isSelected = selection == section
        return Button {
            selection = section
        } label: {
            HStack(spacing: 9) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(section.title)
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundColor(isSelected ? .white : textColor)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? appearance.accent : Color.clear))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension Color {
    /// Surface hex values from `SurfacePalette` are always valid.
    init(hex: String) {
        self = ColorHex.color(from: hex) ?? .clear
    }
}
