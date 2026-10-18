import AppKit
import SwiftUI

// Main-window journal views (design/DESIGN.md section 4 and 8).

// MARK: - Recording row

enum RecordingRowStyle {
    /// The pinned latest card: large text, actions always visible.
    case latest
    /// A journal row: time column on the left, actions in a pill on hover.
    case journal
}

struct RecordingRow: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    let recording: Recording
    let searchQuery: String
    var style: RecordingRowStyle = .journal
    let onDelete: () -> Void
    let onRegenerate: () -> Void
    @StateObject private var audioRecorder = AudioRecorder.shared
    @State private var showTranscription = false
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var isPlaying: Bool {
        audioRecorder.isPlaying && audioRecorder.currentlyPlayingURL == recording.url
    }

    private var isPending: Bool {
        recording.status == .pending || recording.status == .converting || recording.status == .transcribing
    }

    private var isRegenerating: Bool {
        recording.isRegeneration && isPending
    }

    private var statusText: String {
        switch recording.status {
        case .pending: return "In queue..."
        case .converting: return "Converting..."
        case .transcribing: return "Transcribing..."
        case .completed: return ""
        case .failed: return "Failed"
        }
    }

    private var displayText: String {
        if recording.transcription.isEmpty || recording.transcription == "Starting transcription..." || recording.transcription == "In queue..." {
            return ""
        }
        return recording.transcription
    }

    // Same visibility rules as the old row. The latest card only drops the hover requirement.
    private var canPlayAndCopy: Bool { !isPending && recording.status != .failed }
    private var canRegenerate: Bool { recording.status == .completed || recording.status == .failed }
    private var showsPlayAndCopy: Bool { canPlayAndCopy && (style == .latest || isHovered || isPlaying) }
    private var showsRegenerate: Bool { canRegenerate && (style == .latest || isHovered) }
    private var showsDelete: Bool {
        style == .latest || isHovered || isPlaying || (isPending && !isRegenerating) || recording.status == .failed
    }
    private var showsActions: Bool { showsPlayAndCopy || showsRegenerate || showsDelete }

    var body: some View {
        switch style {
        case .latest: latestCard
        case .journal: journalRow
        }
    }

    // MARK: Latest card

    private var latestMeta: String {
        let day = JournalLayout.dayTitle(for: recording.timestamp, now: Date(), calendar: .current, locale: .current)
        let time = recording.timestamp.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(time) · \(TextUtil.formatDuration(recording.duration))"
    }

    private var latestCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("LATEST")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(ThemePalette.iconAccent(colorScheme))
                Text(latestMeta)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            statusContent(textSize: 14, lineSpacing: 3)

            if showsActions {
                HStack(spacing: 12) {
                    if showsPlayAndCopy {
                        Button(action: copyText) {
                            Text("Copy")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 24)
                                .background(appearance.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Copy entire text")
                    }
                    Spacer(minLength: 0)
                    actionButtons
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, ThemePalette.cardContentScheme(colorScheme))
        .background(ThemePalette.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ThemePalette.cardBorder(colorScheme), lineWidth: 1))
        .onHover { isHovered = $0 }
    }

    // MARK: Journal row

    private var journalRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.timestamp, style: .time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Text(TextUtil.formatDuration(recording.duration))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            .frame(width: 62, alignment: .leading)

            statusContent(textSize: 14, lineSpacing: 3)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemePalette.hoverRowSurface(colorScheme))
                .opacity(isHovered ? 1 : 0)
        )
        .overlay(alignment: .topTrailing) {
            if showsActions {
                actionOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isPlaying)
    }

    /// Actions over the right edge of the row, with a short fade in the row's surface color behind them.
    private var actionOverlay: some View {
        let surface = ThemePalette.hoverRowSurface(colorScheme)
        return HStack(spacing: 0) {
            // Short fade so text slides out from under the actions instead of being cut.
            LinearGradient(colors: [surface.opacity(0), surface], startPoint: .leading, endPoint: .trailing)
                .frame(width: 24)
            actionButtons
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .environment(\.colorScheme, ThemePalette.cardContentScheme(colorScheme))
                .background(surface)
                .padding(.trailing, 4)
                .background(surface)
        }
        .fixedSize()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
        .padding(.trailing, 2)
    }

    // MARK: Actions (the same four as before: play, copy, regenerate, delete)

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recording.transcription, forType: .string)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if showsPlayAndCopy {
                Button(action: {
                    if isPlaying {
                        audioRecorder.stopPlaying()
                    } else {
                        audioRecorder.playRecording(url: recording.url)
                    }
                }) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isPlaying ? .red : ThemePalette.iconAccent(colorScheme))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                if style == .journal {
                    Button(action: copyText) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy entire text")
                }
            }

            if showsRegenerate {
                Button(action: onRegenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Regenerate transcription")
            }

            if showsDelete {
                Button(action: {
                    if isPlaying {
                        audioRecorder.stopPlaying()
                    }
                    onDelete()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
    }

    // MARK: Status and text (unchanged content, restyled)

    @ViewBuilder
    private func statusContent(textSize: CGFloat, lineSpacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isPending && !isRegenerating {
                VStack(alignment: .leading, spacing: 4) {
                    if let sourceFileName = recording.sourceFileName {
                        Text(sourceFileName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    progressLine
                }
            }

            if isRegenerating {
                progressLine
                    .transition(.opacity)
            }

            if recording.status == .failed {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Transcription failed")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if !recording.transcription.isEmpty {
                        Text(recording.transcription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if !displayText.isEmpty {
                ZStack(alignment: .topLeading) {
                    TranscriptionView(
                        transcribedText: displayText,
                        searchQuery: searchQuery,
                        isExpanded: $showTranscription,
                        textSize: textSize,
                        lineSpacing: lineSpacing
                    )

                    if isRegenerating {
                        ShimmerOverlay()
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    }
                }
            } else if !isPending {
                Text("No speech detected")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: isRegenerating)
    }

    private var progressLine: some View {
        HStack(spacing: 6) {
            if recording.status == .pending {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: CGFloat(recording.progress))
                        .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: recording.progress)
                }
                .frame(width: 16, height: 16)

                Text("\(Int(recording.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: recording.progress)
            }

            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Shimmer

struct ShimmerOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        let panel = ThemePalette.panelSurface(colorScheme)
        let mid = ThemePalette.textMix(colorScheme, amount: 0.12)
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 6)
                .fill(panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [panel, mid, panel], startPoint: .leading, endPoint: .trailing))
                        .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Transcription text

struct TranscriptionView: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    let transcribedText: String
    let searchQuery: String
    @Binding var isExpanded: Bool
    var textSize: CGFloat = 14
    var lineSpacing: CGFloat = 3
    @Environment(\.colorScheme) private var colorScheme

    @State private var highlightedAttributedString: AttributedString?
    @State private var computeTask: Task<Void, Never>?

    private var hasMoreLines: Bool {
        !transcribedText.isEmpty && transcribedText.count > 150
    }

    private var highlightedText: Text {
        guard !searchQuery.isEmpty else {
            return Text(transcribedText)
        }
        if let attributed = highlightedAttributedString {
            return Text(attributed)
        }
        return Text(transcribedText)
    }

    private func computeHighlighting() {
        computeTask?.cancel()

        guard !searchQuery.isEmpty else {
            highlightedAttributedString = nil
            return
        }

        let text = transcribedText
        let query = searchQuery

        computeTask = Task.detached(priority: .userInitiated) {
            var attributedString = AttributedString(text)
            let searchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

            var searchStartIndex = text.startIndex
            while let range = text.range(of: query, options: searchOptions, range: searchStartIndex..<text.endIndex) {
                guard !Task.isCancelled else { return }
                if let attributedRange = Range(range, in: attributedString) {
                    attributedString[attributedRange].backgroundColor = .yellow
                    attributedString[attributedRange].foregroundColor = .black
                }
                searchStartIndex = range.upperBound
            }

            guard !Task.isCancelled else { return }

            let highlighted = attributedString
            await MainActor.run {
                self.highlightedAttributedString = highlighted
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if isExpanded {
                    ScrollView {
                        highlightedText
                            .font(.system(size: textSize))
                            .lineSpacing(lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                if hasMoreLines {
                                    isExpanded.toggle()
                                }
                            }
                    )
                } else {
                    if hasMoreLines {
                        Button(action: { isExpanded.toggle() }) {
                            highlightedText
                                .font(.system(size: textSize))
                                .lineSpacing(lineSpacing)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        highlightedText
                            .font(.system(size: textSize))
                            .lineSpacing(lineSpacing)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }

            if hasMoreLines {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show less" : "Show more")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(ThemePalette.linkText(colorScheme))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(ThemePalette.linkText(colorScheme).opacity(colorScheme == .dark ? 0.16 : 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            computeHighlighting()
        }
        .onChange(of: searchQuery) { _, _ in
            computeHighlighting()
        }
        .onChange(of: transcribedText) { _, _ in
            computeHighlighting()
        }
        .onDisappear {
            computeTask?.cancel()
        }
    }
}

// MARK: - Day group surface

/// One rounded card per day: the rows on the card color with hairlines between them.
struct JournalGroupSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        VStack(spacing: 0, content: content)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.colorScheme, ThemePalette.cardContentScheme(colorScheme))
            .background(ThemePalette.cardBackground(colorScheme))
            .clipShape(shape)
            .overlay(shape.stroke(ThemePalette.cardBorder(colorScheme), lineWidth: 1))
    }
}

// MARK: - Day header

struct JournalDayHeader: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(ThemePalette.secondaryText(colorScheme))
            .padding(.top, 14)
            .padding(.bottom, 6)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 1pt divider in the border color.
struct Hairline: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(ThemePalette.panelBorder(colorScheme))
            .frame(height: 1)
            .padding(.horizontal, 6)
    }
}

// MARK: - Empty state

struct JournalEmptyState: View {
    let isSearching: Bool
    let shortcut: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "mic.fill")
                .font(.system(size: 20))
                .foregroundColor(ThemePalette.accentText(colorScheme))
                .frame(width: 52, height: 52)
                .background(ThemePalette.accentText(colorScheme).opacity(colorScheme == .dark ? 0.16 : 0.12))
                .clipShape(Circle())

            if isSearching {
                Text("No results found")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ThemePalette.text(colorScheme))
                Text("Try different search terms")
                    .font(.system(size: 13))
                    .foregroundColor(ThemePalette.secondaryText(colorScheme))
            } else {
                Text("No recordings yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ThemePalette.text(colorScheme))
                VStack(spacing: 4) {
                    Text(shortcut.isEmpty ? "Press the record button to get started." : "Press the record button to get started,")
                    if !shortcut.isEmpty {
                        HStack(spacing: 5) {
                            Text("or hit")
                            Text(shortcut)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ThemePalette.panelSurface(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1))
                            Text("anywhere to open the mini recorder.")
                        }
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(ThemePalette.secondaryText(colorScheme))
                .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Drop an audio file anywhere in this window to transcribe it")
                }
                .font(.system(size: 12))
                .foregroundColor(ThemePalette.secondaryText(colorScheme))
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Overlay scrim with a card

/// Window tint at 55% with a centered card. Used by the model loading overlay and the file drop overlay.
struct OverlayScrimCard<Content: View>: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @Environment(\.colorScheme) private var colorScheme
    var dashedOutline = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        ZStack {
            appearance.windowBaseColor(for: colorScheme).opacity(0.55)
            content()
                .padding(.vertical, 18)
                .padding(.horizontal, 26)
                .environment(\.colorScheme, ThemePalette.cardContentScheme(colorScheme))
                .background(ThemePalette.cardBackground(colorScheme))
                .clipShape(shape)
                .overlay(shape.stroke(ThemePalette.cardBorder(colorScheme), lineWidth: 1))
                .overlay {
                    if dashedOutline {
                        shape.inset(by: 6).stroke(appearance.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 4)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Title bar click target

/// A click target that never starts a window drag. The search icon lives in the title bar row,
/// where a plain SwiftUI button can lose the click to the window's drag handling. The rest of
/// the row still drags the window.
struct TitlebarClickTarget: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> ClickView {
        let view = ClickView()
        view.action = action
        return view
    }

    func updateNSView(_ view: ClickView, context: Context) {
        view.action = action
    }

    final class ClickView: NSView {
        var action: (() -> Void)?
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {}
        override func mouseUp(with event: NSEvent) {
            if bounds.contains(convert(event.locationInWindow, from: nil)) { action?() }
        }
    }
}
