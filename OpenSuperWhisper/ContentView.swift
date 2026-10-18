//
//  ContentView.swift
//  OpenSuperWhisper
//
//  Created by user on 05.02.2025.
//

import AVFoundation
import Combine
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class ContentViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var isBlinking = false
    @Published var recorder: AudioRecorder = .shared
    @Published var transcriptionService = TranscriptionService.shared
    @Published var transcriptionQueue = TranscriptionQueue.shared
    @Published var recordingStore = RecordingStore.shared
    @Published var recordings: [Recording] = []
    @Published var isLoadingMore = false
    @Published var canLoadMore = true
    @Published var recordingDuration: TimeInterval = 0
    @Published var microphoneService = MicrophoneService.shared
    @Published var shouldClearSearch = false
    
    @Published private(set) var loadingError: String?
    private var pageTask: Task<Void, Never>?
    private var pageRequestID: UUID?
    private let fetchPage: (String, Int, Int) async throws -> [Recording]
    private var currentPage = 0
    private let pageSize = 100
    private var currentSearchQuery = ""
    private var blinkTimer: Timer?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(fetchPage: ((String, Int, Int) async throws -> [Recording])? = nil) {
        self.fetchPage = fetchPage ?? { query, limit, offset in
            if query.isEmpty {
                return try await RecordingStore.shared.fetchRecordings(limit: limit, offset: offset)
            }
            return try await RecordingStore.shared.searchRecordingsAsync(query: query, limit: limit, offset: offset)
        }
        recorder.$isConnecting
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnecting in
                guard let self = self else { return }
                if isConnecting && self.recorder.isConnecting && RecordingSessionController.shared.isCapturing && self.state != .decoding {
                    self.state = .connecting
                    self.stopBlinking()
                    self.stopDurationTimer()
                    self.recordingDuration = 0
                } else if !isConnecting && !self.recorder.isConnecting && !self.recorder.isRecording && self.state == .connecting {
                    // A failed start clears isConnecting without ever recording.
                    self.state = .idle
                }
            }
            .store(in: &cancellables)
        
        recorder.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                if isRecording && self.recorder.isRecording && RecordingSessionController.shared.isCapturing && self.state != .decoding {
                    self.state = .recording
                    self.startBlinking()
                    self.startDurationTimerIfNeeded()
                } else if !isRecording && !self.recorder.isRecording && self.state == .recording {
                    self.state = .idle
                    self.stopBlinking()
                    self.stopDurationTimer()
                    self.recordingDuration = 0
                }
            }
            .store(in: &cancellables)
    }
    
    func loadInitialData() {
        search(query: "")
    }

    func loadMore() {
        guard !isLoadingMore && canLoadMore else { return }
        isLoadingMore = true
        loadingError = nil
        let id = UUID()
        pageRequestID = id
        let page = currentPage
        let query = currentSearchQuery
        let limit = pageSize
        pageTask = Task {
            defer {
                if pageRequestID == id {
                    isLoadingMore = false
                    pageTask = nil
                }
            }
            do {
                let result = try await fetchPage(query, limit, page * limit)
                try Task.checkCancellation()
                guard pageRequestID == id else { return }
                if page == 0 { recordings = result }
                else { recordings.append(contentsOf: result) }
                canLoadMore = result.count == limit
                currentPage = page + 1
            } catch {
                guard pageRequestID == id, !Task.isCancelled else { return }
                loadingError = error.localizedDescription
            }
        }
    }

    func search(query: String) {
        pageTask?.cancel()
        pageRequestID = nil
        isLoadingMore = false
        currentSearchQuery = query
        currentPage = 0
        canLoadMore = true
        recordings = []
        loadMore()
    }

    func handleProgressUpdate(id: UUID, transcription: String?, progress: Float, status: RecordingStatus, isRegeneration: Bool?) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            if let transcription = transcription {
                recordings[index].transcription = transcription
            }
            recordings[index].progress = progress
            recordings[index].status = status
            if let isRegeneration = isRegeneration {
                recordings[index].isRegeneration = isRegeneration
            }
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        recordingStore.deleteRecording(recording)
    }
    
    func deleteAllRecordings() {
        recordingStore.deleteAllRecordings()
    }

    var isRecording: Bool {
        recorder.isRecording
    }
    
    /// The main window only triggers the shared dictation pipeline (the same one the hotkey
    /// uses, owned by the indicator), so closing this window cannot interrupt a dictation.
    /// The state published here just mirrors the recorder.
    func startRecording() {
        guard microphoneService.getActiveMicrophone() != nil else { return }
        guard !RecordingSessionController.shared.hasSession else { return }
        IndicatorWindowManager.shared.beginDictation()
    }

    func startDecoding() {
        RecordingSessionController.shared.requestStop()
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartTime = nil
    }
    
    private func startDurationTimerIfNeeded() {
        guard durationTimer == nil else { return }
        if recordingStartTime == nil {
            recordingStartTime = Date()
            recordingDuration = 0
        }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let startTime = Date()
            Task { @MainActor in
                if let recordingStartTime = self.recordingStartTime {
                    self.recordingDuration = startTime.timeIntervalSince(recordingStartTime)
                }
            }
        }
        RunLoop.main.add(durationTimer!, forMode: .common)
    }

    private func startBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.isBlinking.toggle()
            }
        }
        RunLoop.main.add(blinkTimer!, forMode: .common)
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        isBlinking = false
    }
}

struct ContentView: View {
    @ObservedObject private var errors = AppErrorCenter.shared
    @ObservedObject private var appearance = AppearanceStore.shared
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var permissionsManager = PermissionsManager()
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var showDeleteConfirmation = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isSearchOpen = false
    @FocusState private var isSearchFocused: Bool
    @State private var searchFieldFrame: CGRect = .zero
    @State private var searchOpenedAt = Date.distantPast
    @State private var outsideClickMonitor: Any?

    private var currentShortcutDescription: String {
        RecordingTriggerDescription.describe(
            mouseButton: MouseButton(rawValue: AppPreferences.shared.mouseButtonHotkey) ?? .none,
            modifierKey: ModifierKey(rawValue: AppPreferences.shared.modifierOnlyHotkey) ?? .none,
            keyCombination: KeyboardShortcuts.getShortcut(for: .toggleRecord)?.description
        )
    }

    private func performSearch(_ query: String) {
        searchTask?.cancel()
        
        if query.isEmpty {
            // Nothing was searched yet, so there is nothing to reload (and the scroll position stays).
            guard !debouncedSearchText.isEmpty else { return }
            debouncedSearchText = ""
            viewModel.search(query: "")
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.debouncedSearchText = query
                viewModel.search(query: query)
            }
        }
    }

    private var layout: JournalLayout.Layout {
        JournalLayout.layout(
            recordings: viewModel.recordings,
            searchQuery: debouncedSearchText,
            now: Date(),
            calendar: .current,
            locale: .current
        )
    }

    private func openSearch() {
        if isSearchOpen {
            isSearchFocused = true
            return
        }
        searchOpenedAt = Date()
        searchFieldFrame = .zero
        isSearchOpen = true
        installOutsideClickMonitor()
        DispatchQueue.main.async { isSearchFocused = true }
    }

    /// Closes the field and clears the query. Only reloads the list if a search was actually applied.
    private func closeSearch() {
        let hadResults = !debouncedSearchText.isEmpty
        isSearchOpen = false
        isSearchFocused = false
        removeOutsideClickMonitor()
        searchText = ""
        debouncedSearchText = ""
        searchTask?.cancel()
        if hadResults { viewModel.search(query: "") }
    }

    /// A click outside the field closes it, but only while it is empty. With text, the results stay
    /// so a click on Copy (or anything else) doesn't wipe them.
    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let bounds = event.window?.contentView?.bounds else { return event }
            let height = bounds.height
            let point = CGPoint(x: event.locationInWindow.x, y: height - event.locationInWindow.y)
            if SearchClickRule.shouldClose(
                isOpen: isSearchOpen,
                queryIsEmpty: searchText.isEmpty,
                point: point,
                fieldFrame: searchFieldFrame,
                // Clicks in the title strip (the search accessory, window drag) never close the field.
                iconFrame: CGRect(x: 0, y: 0, width: bounds.width, height: Self.titleStripHeight),
                secondsSinceOpened: Date().timeIntervalSince(searchOpenedAt)
            ) {
                DispatchQueue.main.async { closeSearch() }
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
    }

    private func deleteAction(_ recording: Recording) -> () -> Void {
        { viewModel.deleteRecording(recording) }
    }

    private func regenerateAction(_ recording: Recording) -> () -> Void {
        { Task { await TranscriptionQueue.shared.requeueRecording(recording) } }
    }

    /// Height of the title bar row (the traffic lights' centre is about 16pt below the window top).
    private static let titleStripHeight: CGFloat = 32

    /// Empty strip under the traffic lights. Nothing clickable lives here: the search button is a
    /// native title bar accessory, and the strip drags the window.
    private var titleStrip: some View {
        Color.clear.frame(height: Self.titleStripHeight)
    }

    /// The search field sits below the title bar row, above the pinned card.
    private var searchField: some View {
        HStack(spacing: 6) {
            Button(action: closeSearch) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ThemePalette.secondaryText(colorScheme))
            }
            .buttonStyle(.plain)
            .help("Close search")

            TextField("Search in transcriptions", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFocused)
                .onChange(of: searchText) { _, newValue in
                    performSearch(newValue)
                }
                .onKeyPress(.escape) {
                    SearchEscapeGuard.shared.searchHandledEscape()
                    closeSearch()
                    return .handled
                }

            if searchText.isEmpty {
                Text("Esc")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(ThemePalette.secondaryText(colorScheme))
            } else {
                Button(action: {
                    searchText = ""
                    isSearchFocused = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ThemePalette.secondaryText(colorScheme))
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(ThemePalette.panelSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { searchFieldFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in searchFieldFrame = frame }
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var journal: some View {
        let layout = layout
        let lastID = layout.groups.last?.recordings.last?.id ?? layout.pinned?.id
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if let pinned = layout.pinned {
                    RecordingRow(
                        recording: pinned,
                        searchQuery: debouncedSearchText,
                        style: .latest,
                        onDelete: deleteAction(pinned),
                        onRegenerate: regenerateAction(pinned)
                    )
                    .id(pinned.id)
                    .onAppear {
                        if pinned.id == lastID { viewModel.loadMore() }
                    }
                }

                ForEach(layout.groups, id: \.day) { group in
                    JournalDayHeader(title: group.title)
                    JournalGroupSurface {
                        ForEach(Array(group.recordings.enumerated()), id: \.element.id) { index, recording in
                            if index > 0 { Hairline() }
                            RecordingRow(
                                recording: recording,
                                searchQuery: debouncedSearchText,
                                style: .journal,
                                onDelete: deleteAction(recording),
                                onRegenerate: regenerateAction(recording)
                            )
                            .id(recording.id)
                            .onAppear {
                                if recording.id == lastID { viewModel.loadMore() }
                            }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var recordButton: some View {
        Button(action: {
            if viewModel.isRecording {
                viewModel.startDecoding()
            } else {
                viewModel.startRecording()
            }
        }) {
            if viewModel.transcriptionService.isTranscribing || viewModel.state == .connecting {
                ProgressView()
                    .scaleEffect(1.0)
                    .frame(width: 58, height: 58)
                    .contentTransition(.symbolEffect(.replace))
            } else {
                MainRecordButton(isRecording: viewModel.isRecording)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.transcriptionService.isLoading || viewModel.transcriptionService.isTranscribing || viewModel.transcriptionQueue.isProcessing || viewModel.state == .decoding || viewModel.microphoneService.availableMicrophones.isEmpty)
        .help(currentShortcutDescription.isEmpty ? "Record" : "Record\n\(currentShortcutDescription) opens the mini recorder")
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isRecording)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.state)
    }

    private func bottomIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundColor(ThemePalette.secondaryText(colorScheme))
            .frame(width: 32, height: 32)
            .background(ThemePalette.panelSurface(colorScheme))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var bottomRow: some View {
        ZStack {
            HStack(spacing: 12) {
                MicrophonePickerIconView(microphoneService: viewModel.microphoneService)

                Spacer()

                if !viewModel.recordings.isEmpty {
                    Button(action: { showDeleteConfirmation = true }) {
                        bottomIcon("trash")
                    }
                    .buttonStyle(.plain)
                    .help("Delete all recordings")
                    .confirmationDialog(
                        "Delete All Recordings",
                        isPresented: $showDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete All", role: .destructive) {
                            viewModel.deleteAllRecordings()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to delete all recordings? This action cannot be undone.")
                    }
                    .interactiveDismissDisabled()
                }

                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    bottomIcon("gear")
                }
                .buttonStyle(.plain)
                .help("Settings")
            }

            recordButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    var body: some View {
        VStack {
            if permissionsManager.hasCompletedInitialCheck,
               !permissionsManager.isMicrophonePermissionGranted
                || !permissionsManager.isAccessibilityPermissionGranted
            {
                PermissionsView(permissionsManager: permissionsManager)
            } else {
                VStack(spacing: 0) {
                    titleStrip
                    if isSearchOpen { searchField }

                    // The list is its own flexible region, so it scrolls fully above the bottom row.
                    Group {
                        if viewModel.recordings.isEmpty && !viewModel.isLoadingMore {
                            JournalEmptyState(isSearching: !debouncedSearchText.isEmpty, shortcut: currentShortcutDescription)
                        } else {
                            journal
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.recordings.count)
                    .animation(.easeInOut(duration: 0.2), value: debouncedSearchText.isEmpty)

                    bottomRow
                }
                .ignoresSafeArea(.container, edges: .top)
            }
        }
        .frame(minWidth: 400, idealWidth: 450)
        .background(AppWindowBackground().ignoresSafeArea())
        .onAppear {
            viewModel.loadInitialData()
        }
        .onReceive(NotificationCenter.default.publisher(for: RecordingStore.recordingProgressDidUpdateNotification)) { notification in
            guard let userInfo = notification.userInfo,
                  let id = userInfo["id"] as? UUID,
                  let progress = userInfo["progress"] as? Float,
                  let status = userInfo["status"] as? RecordingStatus else { return }
            
            let transcription = userInfo["transcription"] as? String
            let isRegeneration = userInfo["isRegeneration"] as? Bool
            
            viewModel.handleProgressUpdate(
                id: id,
                transcription: transcription,
                progress: progress,
                status: status,
                isRegeneration: isRegeneration
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: RecordingStore.recordingsDidUpdateNotification)) { _ in
            viewModel.loadInitialData()
        }
        .overlay {
            let isPermissionsGranted = permissionsManager.isMicrophonePermissionGranted
                && permissionsManager.isAccessibilityPermissionGranted

            if viewModel.transcriptionService.isLoading && isPermissionsGranted {
                OverlayScrimCard {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 22, height: 22)
                            .tint(ThemePalette.iconAccent(colorScheme))
                        Text("Loading Whisper Model...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .alert(item: $errors.issue) { issue in
            Alert(title: Text(issue.title), message: Text(issue.message), dismissButton: .default(Text("OK")))
        }
        .onReceive(viewModel.$loadingError.compactMap { $0 }) { message in
            errors.report("Recordings could not be loaded", message: message)
        }
        .onReceive(viewModel.transcriptionService.$loadingError.compactMap { $0 }) { message in
            errors.report("Model could not be loaded", message: message)
        }
        .fileDropHandler()
        .onChange(of: isSearchFocused) { _, focused in
            SearchEscapeGuard.shared.isSearchFieldFocused = focused
        }
        .onDisappear { removeOutsideClickMonitor() }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in openSearch() }
        .onChange(of: viewModel.shouldClearSearch) { _, shouldClear in
            if shouldClear {
                searchText = ""
                debouncedSearchText = ""
                isSearchOpen = false
                removeOutsideClickMonitor()
                searchTask?.cancel()
                viewModel.shouldClearSearch = false
            }
        }
        .tint(appearance.accentColor)
    }
}

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Required Permissions")
                .font(.title)
                .padding()

            PermissionRow(
                isGranted: permissionsManager.isMicrophonePermissionGranted,
                title: "Microphone Access",
                description: "Required for audio recording",
                action: {
                    permissionsManager.requestMicrophonePermissionOrOpenSystemPreferences()
                }
            )

            PermissionRow(
                isGranted: permissionsManager.isAccessibilityPermissionGranted,
                title: "Accessibility Access",
                description: "Required for global keyboard shortcuts",
                action: { permissionsManager.openSystemPreferences(for: .accessibility) }
            )

            Spacer()
        }
        .padding()
    }
}

struct PermissionRow: View {
    let isGranted: Bool
    let title: String
    let description: String
    let action: () -> Void
    @ObservedObject private var appearance = AppearanceStore.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isGranted ? .green : .red)

                Text(title)
                    .font(.headline)

                Spacer()

                if !isGranted {
                    Button("Grant Access") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(ThemePalette.panelSurface(colorScheme))
        .cornerRadius(10)
    }
}

struct MicrophonePickerIconView: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @ObservedObject var microphoneService: MicrophoneService
    @State private var showMenu = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var builtInMicrophones: [MicrophoneService.AudioDevice] {
        microphoneService.availableMicrophones.filter { $0.isBuiltIn }
    }
    
    private var externalMicrophones: [MicrophoneService.AudioDevice] {
        microphoneService.availableMicrophones.filter { !$0.isBuiltIn }
    }
    
    var body: some View {
        Button(action: {
            showMenu.toggle()
        }) {
            Image(systemName: microphoneService.availableMicrophones.isEmpty ? "mic.slash" : "mic.fill")
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(ThemePalette.panelSurface(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(microphoneService.currentMicrophone?.displayName ?? "Select microphone")
        .popover(isPresented: $showMenu, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                if microphoneService.availableMicrophones.isEmpty {
                    Text("No microphones available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(builtInMicrophones) { microphone in
                        Button(action: {
                            microphoneService.selectMicrophone(microphone)
                            showMenu = false
                        }) {
                            HStack {
                                Text(microphone.displayName)
                                Spacer()
                                if let current = microphoneService.currentMicrophone,
                                   current.id == microphone.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !builtInMicrophones.isEmpty && !externalMicrophones.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    
                    ForEach(externalMicrophones) { microphone in
                        Button(action: {
                            microphoneService.selectMicrophone(microphone)
                            showMenu = false
                        }) {
                            HStack {
                                Text(microphone.displayName)
                                Spacer()
                                if let current = microphoneService.currentMicrophone,
                                   current.id == microphone.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minWidth: 200)
            .padding(.vertical, 8)
        }
    }
}

struct MainRecordButton: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    let isRecording: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var buttonColor: Color {
        isRecording ? .red : ThemePalette.recordButtonBase(colorScheme, accent: appearance.accentColor)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(buttonColor.opacity(0.18))
                .frame(width: 58, height: 58)
            Circle()
                .fill(buttonColor)
                .frame(width: 48, height: 48)
                .shadow(color: buttonColor.opacity(isRecording ? 0.5 : 0.35), radius: 12, x: 0, y: 0)
        }
        .frame(width: 58, height: 58)
        .scaleEffect(isRecording ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
    }
}

/// Main-window surfaces. A thin shim over `SurfacePalette`, through `AppearanceStore`,
/// so cards, search and buttons follow the window color and the card color option.
enum ThemePalette {
    @MainActor
    private static func surface(_ hex: String, opacity: Double) -> Color {
        (ColorHex.color(from: hex) ?? .clear).opacity(opacity)
    }

    @MainActor
    static func panelSurface(_ scheme: ColorScheme) -> Color {
        let store = AppearanceStore.shared
        return surface(store.surfaces(for: scheme).panel, opacity: store.surfaceOpacity)
    }

    @MainActor
    static func panelBorder(_ scheme: ColorScheme) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).border, opacity: 1)
    }

    @MainActor
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        let store = AppearanceStore.shared
        return surface(store.surfaces(for: scheme).card, opacity: store.surfaceOpacity)
    }

    @MainActor
    static func cardBorder(_ scheme: ColorScheme) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).border, opacity: 1)
    }

    /// The scheme the content of a card should render in, so system text colors stay readable
    /// on a custom card color (for example Paper in dark mode).
    @MainActor
    static func cardContentScheme(_ scheme: ColorScheme) -> ColorScheme {
        SurfacePalette.isLightCard(AppearanceStore.shared.surfaces(for: scheme).card) ? .light : .dark
    }

    static func recordButtonBase(_ scheme: ColorScheme, accent: Color? = nil) -> Color {
        accent ?? (scheme == .dark
            ? .white
            : Color(red: 0.35, green: 0.60, blue: 0.92))
    }

    /// Text-sized accent drawn on a card (play icon, "Show more"). Fills use the accent unchanged.
    @MainActor
    static func iconAccent(_ scheme: ColorScheme) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).cardAccentText, opacity: 1)
    }

    /// Text on the window (day headers, search icon, empty state).
    @MainActor
    static func text(_ scheme: ColorScheme) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).text, opacity: 1)
    }

    @MainActor
    static func secondaryText(_ scheme: ColorScheme) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).secondaryText, opacity: 1)
    }

    /// Text-sized accent drawn directly on the window.
    @MainActor
    static func accentText(_ scheme: ColorScheme) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).accentText, opacity: 1)
    }

    /// The text color mixed into a panel-colored shimmer.
    @MainActor
    static func textMix(_ scheme: ColorScheme, amount: Double) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).text, opacity: amount)
    }

    /// The opaque surface of a hovered journal row (panel at 85% over the card, both opaque),
    /// so the hover actions never show text through them on a translucent window.
    @MainActor
    static func hoverRowSurface(_ scheme: ColorScheme) -> Color {
        let surfaces = AppearanceStore.shared.surfaces(for: scheme)
        return surface(ColorHex.mix(surfaces.card, surfaces.panel, 0.85) ?? surfaces.card, opacity: 1)
    }

    @MainActor
    static func linkText(_ scheme: ColorScheme) -> Color {
        surface(AppearanceStore.shared.surfaces(for: scheme).cardAccentText, opacity: 1)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
