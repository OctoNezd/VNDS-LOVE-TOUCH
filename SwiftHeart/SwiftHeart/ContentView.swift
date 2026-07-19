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