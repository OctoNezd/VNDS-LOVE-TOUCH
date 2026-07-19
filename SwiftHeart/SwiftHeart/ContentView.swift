//
//  ContentView.swift
//  SwiftHeart
//
//  Books-style game picker:
//    - Scrollable grid of horizontal game tiles (landscape aspect ratio)
//    - Each tile: background image fills the tile, bottom strip has icon + title
//    - Tapping a tile opens the save-slot picker sheet
//    - Save slots show screenshot (save1.json.png), last_line, and timestamp
//
//  Arguments passed to Love2D:
//    "GameDirName" [saveSlot]   e.g. "Narcissu 2 - R3.7z" 1
//

import SwiftUI
import Combine

// MARK: - Models

struct Game: Identifiable {
    let id = UUID()
    let dirName: String
    let title: String
    let author: String?
    let iconPath: String?
    let previewPath: String?
    let directoryURL: URL
    var saves: [SaveSlot] = []

    init?(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.dirName = directoryURL.lastPathComponent

        let infoURL = directoryURL.appendingPathComponent("info.txt")
        guard let infoContent = try? String(contentsOf: infoURL, encoding: .utf8) else {
            return nil
        }

        var parsedTitle: String?
        var parsedAuthor: String?
        for line in infoContent.components(separatedBy: .newlines) {
            if let colonRange = line.range(of: ":") {
                let key = String(line[..<colonRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if key == "title"       { parsedTitle  = value }
                else if key == "author" { parsedAuthor = value }
            } else if let eqRange = line.range(of: "=") {
                let key = String(line[..<eqRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[eqRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if key == "title"  && parsedTitle  == nil { parsedTitle  = value }
                if key == "author" && parsedAuthor == nil { parsedAuthor = value }
            }
        }

        self.title  = parsedTitle ?? dirName
        self.author = parsedAuthor

        let iconURL = directoryURL.appendingPathComponent("icon.png")
        self.iconPath = FileManager.default.fileExists(atPath: iconURL.path) ? iconURL.path : nil

        let previewURL = directoryURL.appendingPathComponent("dialog_preview.png")
        if FileManager.default.fileExists(atPath: previewURL.path) {
            self.previewPath = previewURL.path
        } else {
            let thumbURL = directoryURL.appendingPathComponent("thumbnail.png")
            self.previewPath = FileManager.default.fileExists(atPath: thumbURL.path)
                ? thumbURL.path : nil
        }

        self.saves = Game.scanSaves(in: directoryURL)
    }

    /// Scans save1.json … save30.json.
    /// Screenshot is stored at save1.json.png (same path + ".png").
    static func scanSaves(in dir: URL) -> [SaveSlot] {
        (1...30).map { i in
            let saveURL = dir.appendingPathComponent("save\(i).json")
            guard FileManager.default.fileExists(atPath: saveURL.path) else {
                return SaveSlot(number: i, exists: false,
                                timestamp: nil, lastLine: nil, screenshotPath: nil)
            }
            var timestamp: Date?
            var lastLine: String?
            if let data = try? Data(contentsOf: saveURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let ts = json["timestamp"] as? Double {
                    timestamp = Date(timeIntervalSince1970: ts)
                }
                lastLine = json["last_line"] as? String
            }
            // Screenshot: same path as the JSON file + ".png"
            let screenshotURL = saveURL.appendingPathExtension("png")
            let screenshotPath = FileManager.default.fileExists(atPath: screenshotURL.path)
                ? screenshotURL.path : nil
            return SaveSlot(number: i, exists: true,
                            timestamp: timestamp, lastLine: lastLine,
                            screenshotPath: screenshotPath)
        }
    }
}

struct SaveSlot: Identifiable {
    let id = UUID()
    let number: Int
    let exists: Bool
    let timestamp: Date?
    let lastLine: String?
    let screenshotPath: String?
}

// MARK: - In-game save/load coordinator
//
// A singleton ObservableObject that bridges the ObjC/Lua side (which runs on
// the main thread inside a nested CFRunLoop) with SwiftUI sheet presentation.
//
// Usage from ObjC:
//   InGameSlotCoordinator.shared.requestSlot(dirPath:mode:) → Int? (blocks)

// Delegate that fires deliver(nil) when the user swipe-dismisses the sheet.
private final class SlotSheetDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Only fire if not already done (i.e. user swiped down without picking)
        if !InGameSlotCoordinator.shared.isDone {
            InGameSlotCoordinator.shared.isDone = true
            InGameSlotCoordinator.shared.pendingResult = nil
        }
    }
}

final class InGameSlotCoordinator: ObservableObject {

    static let shared = InGameSlotCoordinator()
    private init() {}

    // Keeps the delegate alive for the lifetime of the presented sheet.
    private var sheetDelegate: SlotSheetDelegate?

    // MARK: Published state (SwiftUI observes these)

    /// Non-nil while a sheet should be shown.
    @Published var request: SlotRequest? = nil

    // MARK: Internal signalling (used by the nested-runloop bridge)

    /// Set by the sheet when the user makes a choice; read by the bridge.
    var pendingResult: Int? = nil   // chosen slot number (1-based), or nil = cancel
    var isDone: Bool = false

    // MARK: - Request type

    struct SlotRequest: Identifiable {
        let id = UUID()
        let directoryURL: URL
        let mode: SlotMode          // .save or .load
        let gameTitle: String
    }

    enum SlotMode { case save, load }

    // MARK: - ObjC-callable bridge entry point
    //
    // Called from LoveViewController.mm on the main thread.
    // Presents the SwiftUI slot-picker sheet and blocks (via a nested
    // CFRunLoop) until the user makes a choice.
    // Returns the chosen 1-based slot number wrapped in NSNumber, or nil if cancelled.

    // MARK: - Called from SlotBridge.swift (non-blocking)

    /// Present the sheet and return immediately.  Poll isDone / pendingResult
    /// from the game loop via swiftheart_poll_slot_result().
    func showSheet(dirPath: String, isSave: Bool) {
        let dirURL = URL(fileURLWithPath: dirPath)

        var gameTitle = dirURL.lastPathComponent
        let infoURL = dirURL.appendingPathComponent("info.txt")
        if let infoContent = try? String(contentsOf: infoURL, encoding: .utf8) {
            for line in infoContent.components(separatedBy: .newlines) {
                if let r = line.range(of: ":") {
                    let key = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
                    let val = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if key == "title" { gameTitle = val; break }
                }
            }
        }

        pendingResult = nil
        isDone = false

        // SDL blocks the main thread, so DispatchQueue.main.async items never
        // fire while the game is running.  Instead we present the sheet
        // directly via UIKit — UIKit presentation is driven by the run loop
        // (CADisplayLink), which SDL keeps pumping.
        let req = SlotRequest(directoryURL: dirURL,
                              mode: isSave ? .save : .load,
                              gameTitle: gameTitle)

        // Find the topmost presented view controller.
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              let rootVC = keyWindow.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let sheetView = InGameSlotSheet(request: req)
        let hostingVC = UIHostingController(rootView: sheetView)
        hostingVC.modalPresentationStyle = .pageSheet
        // Wire up the delegate so swipe-dismiss is treated as cancel.
        let delegate = SlotSheetDelegate()
        sheetDelegate = delegate
        hostingVC.presentationController?.delegate = delegate
        topVC.present(hostingVC, animated: true) {
            // presentationController is only available after presentation begins.
            hostingVC.presentationController?.delegate = delegate
        }
    }

    /// Reset state after the C++ side has consumed the result.
    func reset() {
        pendingResult = nil
        isDone = false
    }

    // MARK: - Called by the sheet when the user picks a slot or cancels

    func deliver(slot: Int?) {
        pendingResult = slot
        isDone = true
        request = nil   // dismiss SwiftUI-driven sheet (game picker path)
        // Also dismiss any UIHostingController presented directly via UIKit
        // (in-game path — SDL blocks the main dispatch queue so we use UIKit).
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              let rootVC = keyWindow.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        if topVC !== rootVC {
            topVC.dismiss(animated: true)
        }
    }
}

// MARK: - LoveGameView

struct LoveGameView: UIViewControllerRepresentable {
    let gamePath: String
    var extraArgs: [String] = []
    let onQuit: () -> Void

    func makeUIViewController(context: Context) -> LoveViewController {
        LoveViewController(gamePath: gamePath, extraArgs: extraArgs, onQuit: onQuit)
    }
    func updateUIViewController(_ uiViewController: LoveViewController, context: Context) {}
}

// MARK: - ContentView

struct ContentView: View {
    @State private var isPlayingGame = false
    @State private var games: [Game] = []
    /// Non-nil when a game tile is tapped; drives the save-slot sheet via .sheet(item:).
    @State private var selectedGame: Game? = nil
    @State private var launchArgs: [String] = []
    @State private var showSettings = false

    @ObservedObject private var slotCoordinator = InGameSlotCoordinator.shared

    private var coreLovePath: String {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("core.love").path
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        if isPlayingGame {
            LoveGameView(gamePath: coreLovePath, extraArgs: launchArgs, onQuit: {
                isPlayingGame = false
                launchArgs = []
            })
            .ignoresSafeArea()
            // In-game save/load sheet, triggered by Lua via InGameSlotCoordinator.
            .sheet(item: $slotCoordinator.request) { req in
                InGameSlotSheet(request: req)
            }
        } else {
            NavigationStack {
                if games.isEmpty {
                    emptyState
                        .navigationTitle("SwiftHeart")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar { settingsButton }
                } else {
                    ScrollView {
                        // .adaptive gives 1 column on narrow phones, 2+ on iPad
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 280), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(games) { game in
                                GameTileView(game: game)
                                    .onTapGesture { selectedGame = game }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                    .navigationTitle("SwiftHeart")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar { settingsButton }
                }
            }
            .onAppear { loadGames() }
            .sheet(item: $selectedGame) { game in
                SaveSlotSheet(game: game, onLaunch: { dirName, slot in
                    launchArgs = slot.map { [dirName, String($0)] } ?? [dirName]
                    selectedGame = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isPlayingGame = true
                    }
                })
            }
        }
    }

    @ToolbarContentBuilder
    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .disabled(true)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Games Found")
                .font(.headline)
            Text("Add game folders to the Documents directory via the Files app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if !FileManager.default.fileExists(atPath: coreLovePath) {
                Text("Also place core.love in Documents.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func loadGames() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return }

        games = contents
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("info.txt").path) }
            .compactMap { Game(directoryURL: $0) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

// MARK: - In-game slot picker sheet

/// Presented while a game is running (triggered by Lua via InGameSlotCoordinator).
/// For "save" mode: all 30 slots are selectable (empty slots can be overwritten).
/// For "load" mode: only existing slots are selectable.
struct InGameSlotSheet: View {
    let request: InGameSlotCoordinator.SlotRequest

    private var saves: [SaveSlot] {
        Game.scanSaves(in: request.directoryURL)
    }

    private var isSave: Bool { request.mode == .save }

    var body: some View {
        NavigationStack {
            List {
                if isSave {
                    // Save mode: all 30 slots available
                    Section("Choose a slot to save") {
                        ForEach(saves) { slot in
                            Button {
                                // deliver() handles dismissal via UIKit
                                InGameSlotCoordinator.shared.deliver(slot: slot.number)
                            } label: {
                                SaveSlotRow(slot: slot)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                } else {
                    // Load mode: only existing saves
                    let existing = saves.filter { $0.exists }
                    if existing.isEmpty {
                        Section {
                            Text("No saved games found.")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Section("Choose a save to load") {
                            ForEach(existing) { slot in
                                Button {
                                    InGameSlotCoordinator.shared.deliver(slot: slot.number)
                                } label: {
                                    SaveSlotRow(slot: slot)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                    }
                }
            }
            .navigationTitle(isSave ? "Save Game" : "Load Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        InGameSlotCoordinator.shared.deliver(slot: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Save Slot Sheet (extracted view so .sheet(item:) always has content)

struct SaveSlotSheet: View {
    let game: Game
    let onLaunch: (String, Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // New Game
                Section {
                    Button {
                        onLaunch(game.dirName, nil)
                        dismiss()
                    } label: {
                        Label("New Game", systemImage: "play.fill")
                            .fontWeight(.semibold)
                    }
                }

                // Occupied slots
                let existing = game.saves.filter { $0.exists }
                if !existing.isEmpty {
                    Section("Saved Games") {
                        ForEach(existing) { slot in
                            Button {
                                onLaunch(game.dirName, slot.number)
                                dismiss()
                            } label: {
                                SaveSlotRow(slot: slot)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }

                // All 30 slots
                Section("All Slots") {
                    ForEach(game.saves) { slot in
                        Button {
                            onLaunch(game.dirName, slot.number)
                            dismiss()
                        } label: {
                            SaveSlotRow(slot: slot)
                        }
                        .disabled(!slot.exists)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Save Slot Row

struct SaveSlotRow: View {
    let slot: SaveSlot

    var body: some View {
        HStack(spacing: 12) {
            // Screenshot thumbnail or placeholder
            Group {
                if let path = slot.screenshotPath,
                   let img = UIImage(contentsOfFile: path) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: slot.exists ? "photo" : "doc")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 80, height: 52)
            .cornerRadius(6)
            .clipped()

            // Text info
            VStack(alignment: .leading, spacing: 3) {
                Text("Save \(slot.number)")
                    .font(.subheadline)
                    .fontWeight(slot.exists ? .semibold : .regular)
                    .foregroundColor(slot.exists ? .primary : .secondary)

                if let ts = slot.timestamp {
                    (Text(ts, style: .date) + Text("  ") + Text(ts, style: .time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let line = slot.lastLine, !line.isEmpty {
                    Text(line)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .italic()
                } else if !slot.exists {
                    Text("Empty")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray3))
                }
            }

            Spacer()

            if slot.exists {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray3))
            }
        }
    }
}

// MARK: - Game Tile View (horizontal / landscape, 16:9)
//
//   ┌──────────────────────────────────────────┐
//   │         background / preview image       │
//   ├──────────────────────────────────────────┤
//   │  [icon]  Title                           │
//   └──────────────────────────────────────────┘

struct GameTileView: View {
    let game: Game

    var body: some View {
        VStack(spacing: 0) {
            // Image area: always exactly 160 pt tall, full width.
            // scaledToFill + clipped ensures the image covers the box
            // regardless of its native aspect ratio.
            ZStack {
                Color(.systemGray5)

                if let path = game.previewPath,
                   let img = UIImage(contentsOfFile: path) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.0, blue: 0.4),
                            Color(red: 0.15, green: 0.0, blue: 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
            .clipped()

            // Bottom strip: icon + title
            HStack(spacing: 10) {
                Group {
                    if let path = game.iconPath,
                       let img = UIImage(contentsOfFile: path) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "book.closed.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                }
                .frame(width: 32, height: 32)
                .background(Color(.systemGray5))
                .cornerRadius(6)
                .clipped()

                Text(game.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(Color(.systemGray6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
    }
}

#Preview {
    ContentView()
}
