# Redesign survey (Step 0)

Read-only survey of the code on `feature/redesign`.
Nothing was run, built or launched.
Line numbers refer to `Settings.swift` and `ContentView.swift`.

## 1. How things work today

### Settings

#### Structure
`SettingsView` is a sheet presented from `ContentView`.
Its size is min(680, screen width - 40) by min(500, screen height - 60).
A segmented `Picker` over Int tags 0-6 sits at the top.
A `switch` below it picks the tab content.
The footer holds Done and the GitHub link.
The background is `AppWindowBackground(opaque: true)`, which is the window color or `windowBackgroundColor`.
Every card is `.background(Color(.controlBackgroundColor).opacity(0.3)).cornerRadius(12)`, copy-pasted about 20 times.
Only `AppearanceSettingsView` has a shared `cardStyle()`.

#### Tab contents
- **Shortcuts:** Recording Trigger (key combo, single modifier or mouse button), Recording Behavior (hold to record, sound on start, Esc cancels without confirmation), and Application (start hidden in the menu bar).
- **Model:** engine picker (Parakeet or Whisper), downloadable model lists, and the models folder.
- **Transcription:** Language Settings (language, Asian autocorrect), Output Options (timestamps, suppress blank audio, space after sentence), Clipboard & Paste (auto-copy, auto-paste), Initial Prompt, and Transcriptions Directory plus retention.
- **Advanced:** Decoding Strategy (beam search, beam size), Model Parameters, and Debug Options.
- **Vocabulary:** Words and Replacements.
- **AI Cleanup:** the master toggle, provider, URL, key, model, reasoning effort and timeout, plus a Test card with samples.
- **Appearance:** Recording indicator (live preview, color, size, background), Accent, and Window (style, tint color, strength), plus Reset.

#### The white flash (not verified)
The cause cannot be confirmed without running the app.
These are the candidates, most likely first:
1. The segmented `NSSegmentedControl` sits directly on a sheet whose NSWindow still has its own system background. Only a SwiftUI layer paints our color, through the safe area. Pressing or hovering the control composites against the unpainted window or hosting layer.
2. `.tint(accent)` is applied to the container, so the control re-renders with a custom tint.
3. Swapping the whole `switch` content on tab change rebuilds the ScrollViews.

A sidebar removes the segmented control, which should remove the trigger.
Setting the window's own `backgroundColor` removes anything unpainted underneath.

### Main window
It is a `WindowGroup` with `.hiddenTitleBar`, default size 450x650, content min width 400.
The background is `AppWindowBackground().ignoresSafeArea()`.
The `AppDelegate` flips `isOpaque` and the window's `backgroundColor` for translucency.

| Element | Styling | Where |
|---|---|---|
| History card | `cardBackground` is white in light and `controlBackgroundColor` in dark. Radius 8, 1pt `cardBorder`, 12pt horizontal padding, 8pt gap. | `RecordingRow`, ~1024-1030 |
| Search bar | `panelSurface` fill, 1pt `panelBorder`, radius 20, padding 10. | ~390-397 |
| Mic, trash and gear buttons | 32x32, radius 8, `panelSurface` and `panelBorder`, secondary-colored icons. | ~572, 603, 1222 |
| Record button | 48pt gradient circle from `recordButtonBase` (the accent), with glow shadow and ring. Red when recording. | `MainRecordButton`, 1290 |
| Palette | Hardcoded RGB in light. Dark uses `Color.gray.opacity(0.1)`, `controlBackgroundColor` and `separatorColor`. The `NSColor` system colors ignore our window tint, which causes the dark clash. | `ThemePalette`, 1337 |

The empty-state chips, the shimmer and the loading overlay (`black.opacity(0.3)`) are also hardcoded.
The indicator is separate: orange states are hardcoded, and the card uses black or white at 0.24 opacity.

### How `AppearanceStore` could extend
1. **Surface derivation:** a pure `SurfacePalette` enum, in the style of `AppearanceResolver`, so it tests without UserDefaults. It takes the window base hex, the scheme and the card option, and returns `card`, `panel` (search bar and buttons), `border` and `separator`. It mixes the window base toward white in light and toward a lighter blue-gray in dark by fixed amounts. That needs a `ColorHex.mix` helper.
2. **Card option:** `cardColorHex` (empty means derived from the window). Accessors `cardFill(for:)`, `panelFill(for:)` and `borderColor(for:)` follow the `windowFill` pattern, and `ThemePalette` becomes a thin shim over them.
3. **Settings cards:** the same card surface, in its opaque variant, replaces the 20 copies of `controlBackgroundColor.opacity(0.3)` through one shared modifier.
4. **Translucent window:** the card should be slightly more opaque than the window, so text stays readable over the blur.

## 2. Proposals

### Sidebar sections and window
Six sections:
1. **General:** Recording Trigger, Recording Behavior, Application, and Clipboard & Paste (moved from Transcription).
2. **Models:** unchanged.
3. **Transcription:** Language, Output Options, Initial Prompt, Storage, and an "Advanced" disclosure holding Decoding, Parameters and Debug. This merges the Advanced tab away.
4. **Vocabulary**
5. **AI Cleanup**
6. **Appearance**

Settings becomes its own window instead of a sheet.
A sheet blocks the main window, and 500pt of height is cramped for a sidebar plus these forms.
Suggested size is about 820x600, resizable, sidebar about 190pt, opened with Cmd-, and by the existing `.openSettings` notification.

One catch: `AppDelegate.isMainAppWindow` treats any titled, non-panel, non-sheet window as the main window.
A Settings window would be mistaken for it and get the transparency and `adoptMainWindow` treatment.
That check needs tightening, for example by identifier.

### Main-window styles
- **A. Soft cards:** today's structure, refined. Cards are radius 12 with a 1pt border, no shadow, and 14pt padding. The search bar is a full capsule filled with the panel color. The bottom buttons are 32pt rounded squares. The record button is a solid accent circle with a soft ring and a smaller glow.
- **B. Floating:** no borders. Cards use a soft shadow and radius 14. The search bar is a capsule with no border. The bottom buttons are circles. The record button is a larger 56pt circle.
- **C. Grouped list:** one rounded surface with hairline dividers between rows, like Messages. The search bar is a 10pt-radius field, the bottom buttons are plain icons, and the record control is a pill with a "Record" label and the shortcut.

### Palettes (accent `#2F7FB8` in both)

| Role | Light | Dark |
|---|---|---|
| Window tint | `#E6EFF6` (today's) | `#161D23` |
| Card | `#FFFFFF` | `#1F2830` |
| Panel (search and buttons) | `#F2F6FA` | `#27323B` |
| Border | `#D5E0EA` | `#2F3C47` |
| Text | `#14202B` | `#E8EEF3` |
| Secondary text | `#5B6B7A` | `#93A3B1` |
| Link and icon accent | `#2F7FB8` | `#4A9AD4` |

In dark, cards go lighter than the window and blue-tinted instead of black.
`#2F7FB8` on dark cards is only about 3.9:1 by estimate, so text-sized accents use `#4A9AD4` and fills keep `#2F7FB8`.
Both palettes ship as derivation rules in `SurfacePalette`, not as a fixed table, so a custom window color still produces matching cards.

### Appearance tab additions
A new Cards card between Accent and Window:
- Card color: Match window (default), plus swatches and a custom picker, with a Reset.
- A live preview showing a sample history card, the search bar and a button.
- Reset to defaults covers the new option.
