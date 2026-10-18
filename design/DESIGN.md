# Beluga redesign: decisions from the Lavish board

Source of truth for Phase 6 Stage 3.
Everything here was decided on `design/redesign.html` or in chat.
Values below are the board's values, so the build should reproduce them.
Where a value was not decided, it says "open".

## 0. Scope and ground rules

- Branch `feature/redesign`, from `develop`.
- Every existing setting and feature keeps working and stays reachable.
- Keep internal names (Xcode project, targets, module `OpenSuperWhisper`).
- Keep the Appearance defaults: accent `#2F7FB8`, window Translucent at 80%, tint `#E6EFF6` light, unless a section below changes them on purpose.
- The dark window tint default changes from `#1D2327` to `#161D23`, to match the locked Blue-gray palette (decided in Stage 3a). Stored custom window colors are unaffected.
- Onboarding is not touched.
- The recording indicator is not touched.
- No Appearance mode switch (System, Light, Dark) in this phase.
- No card style picker.
- Mockups are close, not exact. Real desktops have text and windows behind see-through surfaces.

## 1. Palettes

Both palettes use Beluga blue `#2F7FB8` for fills (record button, Copy button, selected sidebar item, toggles, primary buttons).
Text-sized accents (links, "Show more", play icon, icon accents) use the "accent text" color, because `#2F7FB8` is too weak as text on dark cards.

### Light (approved, starts from today's light mode)

| Role | Hex |
|---|---|
| Window tint | `#E6EFF6` |
| Card | `#FFFFFF` |
| Panel (search, buttons, chips) | `#F2F6FA` |
| Border | `#D5E0EA` |
| Sidebar | `#DCE8F1` |
| Text | `#14202B` |
| Secondary text | `#5B6B7A` |
| Accent text | `#2F7FB8` |
| Control background | `#FFFFFF` |
| Control border | `#C9D6E1` |
| Chip fill (Show more) | `rgba(47,127,184,.12)` |
| Shadow | `rgba(20,40,60,.14)` |

Contrast, computed on the board:
- Text on card: 16.5:1.
- Secondary on card: 5.5:1.
- Accent text on card: 4.3:1. This is just under 4.5:1 for normal-size text, accepted because it matches today's light look. Keep accent text at 13pt or larger and not light-weight.
- White on `#2F7FB8` fill: 4.3:1.
- Card against window: 1.2:1, so cards rely on the 1pt border.

### Dark (locked: Blue-gray)

| Role | Hex |
|---|---|
| Window tint | `#161D23` |
| Card | `#1F2830` |
| Panel | `#27323B` |
| Border | `#2F3C47` |
| Sidebar | `#11171B` |
| Text | `#E8EEF3` |
| Secondary text | `#93A3B1` |
| Accent text | `#4A9AD4` |
| Control background | `#2B3741` |
| Control border | `#3A4854` |
| Chip fill | `rgba(74,154,212,.16)` |
| Shadow | `rgba(0,0,0,.45)` |

Contrast, computed on the board:
- Text on card: 12.8:1.
- Secondary on card: 5.8:1.
- Accent text `#4A9AD4` on card: 4.9:1.
- Accent text on window: 5.6:1.
- `#2F7FB8` as text on card: 3.5:1, which is why text-sized accents use the lifted blue.
- White on `#2F7FB8` fill: 4.3:1.
- Card against window: 1.1:1, so the 1pt border is required, not decoration.

Graphite and Deep sea were evaluated and dropped.

### Accent text (resolved)
Fills always use the accent unchanged.
Light mode: text-sized accents use the accent as is.
Dark mode: text-sized accents use the accent lightened in HSL (hue and saturation kept, lightness raised in 1 point steps) until it reaches 4.5:1 contrast on the card.
An accent that already reaches 4.5:1 is left alone.
Beluga blue on the default dark card resolves to the designed value `#4A9AD4` (pinned, because plain HSL lightening gives a flatter `#4194CF`).
On a custom card color, "text on the card" follows the card: a light card (relative luminance above 0.4) uses the accent as is, a dark card lifts it.

## 2. Surfaces and how they derive from the window color

Cards, panels, borders and the sidebar derive from the window base color, so they never clash with a custom window color.
The derivation is a pure `SurfacePalette` in the style of `AppearanceResolver`, tested without UserDefaults.

Inputs: window base hex (the custom window color, or the per-scheme default), the scheme, the optional card color hex.
Outputs: `card`, `panel`, `border`, `sidebar`, and the opaque variants for Settings.

Rule, measured from the two palettes above (HSL, hue and saturation kept from the window color):
- **Dark:** card = window lightness +4.3 points, panel +8.0, border +11.9, sidebar -2.5.
- **Light:** card = white, panel = window lightness +3.2, border = window lightness -5.7 with saturation scaled to about 0.7, sidebar = window lightness -2.9.
- The fitted constants must reproduce the default tables above exactly for the default window colors. Tests lock that.
- Text, secondary text and accent text come from the scheme table, not from the window color.

Translucent windows:
- The window fill is the tint at the Tint strength (60 to 100%) over the blur.
- Card and panel surfaces are 92% opaque over the window, so text stays readable.
- At the 60% minimum, cards still read as a lighter plate because of the 92% opacity plus the 1pt border.
- Solid uses fully opaque surfaces (alpha 1).
- The System window background option is removed (it clashed with the Beluga surfaces). Window background is Solid or Translucent, default Translucent 80%. A saved "system" value reads as that default. Light and dark still follow macOS.
- Settings always paints the Beluga window color for the current scheme, fully opaque, whatever the main window style is. It never falls back to a macOS system color.

Settings:
- Settings is always opaque and uses the opaque variants of every surface.
- Settings cards use the same derived `card` color, replacing the roughly 20 copies of `Color(.controlBackgroundColor).opacity(0.3)` with one shared modifier.

Card color override (Appearance):
- `cardColorHex` in `AppearanceStore`, empty means "Match window" (derived).
- A custom value replaces `card` only. Panel, border and sidebar keep deriving from the window.
- Pure resolution lives next to `AppearanceResolver` and is tested.

`ThemePalette` becomes a thin shim over these accessors.
The `NSColor` system colors (`controlBackgroundColor`, `separatorColor`, `underPageBackgroundColor`) are no longer used for main-window surfaces.

## 3. Spacing, radii and type

| Item | Value |
|---|---|
| Main window width | min 400, default 450 |
| Window side padding | 16 |
| Window top bar height | 44 |
| Latest card radius | 14 |
| Latest card padding | 16 vertical, 18 horizontal |
| Latest card border | 1pt, `border` color |
| Journal row padding | 10 vertical, 6 horizontal |
| Journal time column | 62 wide, 10 gap |
| Row hover radius | 8 |
| Hairline | 1pt, `border` color |
| Day header | 12pt, semibold, secondary color, sentence case (not uppercase), padding 14 top, 6 bottom, 6 horizontal |
| Body text (rows) | 14pt, line height 1.4 |
| Latest text | 16pt, line height 1.45 |
| Time | 12pt medium, duration 11.5pt secondary |
| Icon buttons (bottom row) | 32x32, radius 8, panel fill, 1pt border |
| Top bar icon button | 28x28, radius 8 |
| Record button | 48pt circle, accent fill, 5pt ring at accent 18%, glow at accent 35% |
| Copy button | height 30, radius 8, padding 14, accent fill, white semibold 13pt |
| Settings card radius | 12 |
| Settings window | about 820x600, resizable |
| Settings sidebar | 190 wide |

## 4. Main window layout

Latest recording pinned at the top, journal below.

Structure, top to bottom:
1. **Top bar (44pt):** traffic lights on the left, a search icon button on the right.
2. **Latest card:** the most recent recording, large.
3. **Journal:** everything else, grouped under day headers.
4. **Bottom row:** mic picker on the left, record button in the center, delete all and settings on the right.

### Top bar and search
- The search icon expands into a field in the top bar, the field replaces the traffic-light-row spacer, radius 8, 1pt border, search icon, placeholder "Search in transcriptions", and a small "Esc" hint at the right.
- Esc closes the field and clears the query, same as the current clear behavior.
- Search results use the same layout. The latest card pinning applies only when the query is empty. With a query, results show as journal rows with highlighting as today.

### Latest card
- Label "LATEST" with "Today", time and duration.
- Large text, 3 lines maximum, with "Show more" and "Show less" under today's rule (see below).
- Prominent Copy button (accent fill) copies the entire text.
- Beside it, the other actions: play or stop, regenerate, delete.
- The latest card shows its four actions all the time (decided).
- The latest recording appears only in this card, never repeated under Today.
- While the latest recording is pending, converting, transcribing or failed, the card shows the same status text, progress ring and failure state that rows show today, in the card.

### Journal
- Day headers: "Today", "Yesterday", then the full date for anything older, for example "October 16, 2026".
- Each row: time (medium) over duration in a narrow left column, text on the right, hairline divider between rows, no boxed cards.
- The first row under a header has no top hairline.
- Pending, converting, transcribing and failed rows keep today's status content (file name, clock or progress ring, status text, "Transcription failed" in red, "No speech detected").

### Hover state and actions (match today's `RecordingRow` exactly)
- Actions appear on hover, in this order: play or stop, copy ("Copy entire text"), regenerate ("Regenerate transcription"), delete.
- Play uses the accent text color and turns red with a stop icon while playing.
- Copy, regenerate and delete use the secondary color.
- Visibility rules stay as today:
  - play and copy: not pending, not failed, and hovered or playing.
  - regenerate: completed or failed, and hovered.
  - delete: hovered, playing, pending (not regenerating), or failed.
- No new actions are added.
- In the journal, the actions sit in a pill at the row's top right (radius 8, card fill, 1pt border, soft shadow), and the row gets the panel fill at 85% with radius 8.
- Row text gets right padding so it does not run under the pill.

### Text and Show more (unchanged behavior)
- Collapsed: 3 lines.
- "Show more" and "Show less" appear only when the text is over 150 characters.
- Expanded: scrollable, max height 200pt.
- Tapping the text toggles when it has more lines.
- Search highlighting is unchanged.
- "Show more" is a chip: link-color text on the chip fill, radius 7, 12pt.

### Bottom row
- Mic picker (icon button, same menu as today), record button, delete all (only when there are recordings, same confirmation as today), settings.
- Record button turns red while recording, as today.
- The "⌥` to show mini recorder" and "Drop audio file here to transcribe" hints leave the bottom row.
- They move to the empty state, and the mini recorder shortcut is also a tooltip on the record button ("Record", "⌥` opens the mini recorder").
- Dropping a file anywhere still works, and shows a full-window drop overlay, restyled with the surfaces and accent from section 8.

### Empty state
- Centered column: a 52pt circle in the chip fill with a mic icon in accent text, title "No recordings yet" (15pt semibold, text color), then "Press the record button to get started, or hit ⌥` anywhere to open the mini recorder." with the shortcut in a small keycap (panel fill, 1pt border, radius 6).
- Below it, a 12pt line with a document icon: "Drop an audio file anywhere in this window to transcribe it".
- A "No results found" state for empty search results keeps today's wording and uses the same layout.
- The bottom row stays visible, with the tooltip on the record button.

### Window background
- `AppWindowBackground` stays as is for the main window (Translucent 80% default).
- The main window is the only window that ever gets translucency.

## 5. Settings window

Settings becomes its own window, opaque, instead of a sheet.

- Opened by Cmd-, and by the existing `.openSettings` notification, which replaces `isSettingsPresented` on `ContentView`.
- About 820x600, resizable, sidebar 190pt.
- Opaque, and the window's own `backgroundColor` is set explicitly to the opaque window color, so nothing unpainted shows under it. This is also the fix for the white flash, together with removing the segmented control.
- Tighten `AppDelegate.isMainAppWindow` to match the main window by identifier, so the Settings window never gets the main window's translucency or `adoptMainWindow` handling. Cover this with a test.
- Closing uses the window's own close button. There is no Done button. The GitHub link moves to the bottom of the sidebar.
- The settings window is a single instance: opening it again focuses it.

### Sidebar
- Items: icon, label, 30pt tall, radius 8, 9pt gap, 10pt horizontal padding.
- Selected item: accent fill, white text.
- Sidebar color is the `sidebar` surface, with a 1pt border on its trailing edge.
- Traffic lights sit at the top of the sidebar.
- Content area: padding 18 top, 22 sides, page title 20pt, scrolls.

### Sections (six, every existing setting stays reachable)
1. **General**
   - Recording Trigger: key combination, single modifier key, mouse button, and their pickers.
   - Recording Behavior: hold to record, play sound on record start, Esc cancels without confirmation.
   - Clipboard & Paste (moved from Transcription): copy to clipboard, paste automatically.
   - Application: start hidden in the menu bar.
2. **Models**
   - Engine picker (Parakeet or Whisper), downloadable model lists, models folder. Unchanged.
3. **Transcription**
   - Language Settings: language, Asian autocorrect.
   - Output Options: show timestamps, suppress blank audio, add space after sentence.
   - Initial Prompt.
   - Transcriptions Directory and retention (`RecordingStorageSettingsView`).
   - An "Advanced" disclosure containing Decoding Strategy (beam search, beam size), Model Parameters, and Debug Options. This replaces the Advanced tab.
4. **Vocabulary**
   - Words and Replacements. Unchanged.
5. **AI Cleanup**
   - Master toggle, provider, URL, key, model, reasoning effort, timeout, and the Test card. Unchanged.
   - Vocabulary and AI Cleanup sit next to each other. There is no "Text" header.
6. **Appearance**
   - See section 6.

A test must assert that the section list covers every setting the old seven tabs covered.

### Controls
- Cards: radius 12, padding 14 vertical and 16 horizontal, 1pt border, card surface (opaque variant).
- Rows: 7pt vertical padding, hairline between rows, label with a 11.5pt secondary caption on the left, control on the right.
- Segmented control: panel fill, 1pt border, radius 8, selected segment uses the control background with a small shadow.
- Toggle: 34x20, off uses the control border color, on uses the accent fill.
- Text fields: control background and control border, radius 6.
- The pane fades out over the last 40pt at the bottom to the window color.

## 6. Appearance tab and the Cards section

Order: Recording indicator, Accent color, Cards (new), Window.
Indicator, Accent and Window sections are unchanged apart from using the shared card modifier.

### Cards section
- Row "Card color" with the caption "Match window follows the window color in light and dark."
- Swatches: Match window (default, selected), then presets, then a custom picker, using the existing `ColorSwatchRow` and `CircleColorPicker`.
- Presets (decided): Match window (default), Paper `#FFFFFF`, Mist `#EEF3F8`, Slate `#2A343D`, Ink `#10151A`, plus the custom picker.
- Text on a custom card follows the card: when the scheme text would drop below 4.5:1 on it, the card content renders in the other scheme (so Paper in dark mode gets dark text).
- A Reset button, disabled when the value is already "Match window". Reset clears the card color only.
- A live preview below, on the window color: a search field, a sample history card, and a button, all drawn with the real surfaces, updating live as the color changes.
- "Reset to defaults" at the bottom of the tab also clears the card color.
- No card style picker.

### Store
- `AppearanceStore.Keys.cardColorHex`, `@Published var cardColorHex`, written to UserDefaults like the other keys, reset in `resetToDefaults()`.
- Defaults tests are updated to include it.

## 7. Where each surface is used

| Surface | Used for |
|---|---|
| Window tint | Main window fill (translucent or solid), Settings window fill |
| Sidebar | Settings sidebar |
| Card | Latest card, Settings cards, hover action pill, tooltip, loading overlay card |
| Panel | Search field, bottom row buttons, hovered row fill, keycaps, segmented control background |
| Border | Card borders, hairlines, button borders |
| Accent fill | Record button, Copy button, selected sidebar item, toggles, primary buttons |
| Accent text | Links, "Show more", play icon, empty-state icon |

## 8. Empty state, shimmer and loading overlay

Approved. They move onto the theme surfaces.

- **Empty state:** as in section 4. The old hardcoded `Color.secondary.opacity(0.2)` keycap becomes the panel fill with a 1pt border.
- **Shimmer** (`ShimmerOverlay`, used while regenerating): a gradient from panel to a 12% text mix to panel, radius 6, instead of white at 40%.
- **Loading overlay** ("Loading Whisper Model..."): replaces the flat `Color.black.opacity(0.3)` and white text with a scrim of the window tint at 55%, and a centered card (card surface, 1pt border, radius 14, padding 18 vertical and 26 horizontal, soft shadow) holding a 22pt spinner in accent text and the title in text color.
- **File drop overlay:** uses the same scrim and card, with the accent for the dashed outline.

## 9. Stage 3 build order

1. Tests first for pure logic:
   - `SurfacePalette` derivation reproduces both default tables for the default window colors, and handles custom window colors and the card color override.
   - Accent text lift for custom accents.
   - Day header grouping: Today, Yesterday, full date for older, including the midnight boundary and time zone.
   - "Latest recording is excluded from the journal" and the empty-query rule for pinning.
   - Show more threshold (over 150 characters) stays as is.
   - `isMainAppWindow` matches only the main window, never the Settings window.
   - Settings sections cover every previous setting.
   - `AppearanceDefaults` and the store include `cardColorHex`, and Reset restores it.
2. Code: surfaces and store, Settings window and sidebar, main window layout, restyled empty state, shimmer and overlays.
3. `./run.sh build` and the test run (derived data outside iCloud).
4. Manual verification by Esequiel, in both modes:
   - Every Settings section reachable, no white flash.
   - Main window layout, hover actions, empty state, search expand and collapse.
   - Appearance changes (including card color) apply live, Reset restores defaults.
   - Dictation and file drop still work.
   - Readability over Translucent backgrounds at 60% and 100% tint strength.

## 10. Open items

None. The four items from the board are resolved above:
- Latest card actions: always visible.
- Card swatches: Match window, Paper, Mist, Slate, Ink, custom.
- Dark accent lift: HSL lightening to 4.5:1 on the card, Beluga blue pinned to `#4A9AD4`.
- Day headers: sentence case, semibold, secondary color.
