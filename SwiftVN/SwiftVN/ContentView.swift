//
//  ContentView.swift
//  SwiftVN
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

struct ContentView: View {
    @State private var isPlayingGame = false
    @State private var games: [Game] = []
    /// Non-nil when a game tile is tapped; drives the save-slot sheet via .sheet(item:).
    @State private var selectedGame: Game? = nil
    @State private var launchArgs: [String] = []
    @State private var showSettings = false

    @ObservedObject private var slotCoordinator = InGameSlotCoordinator.shared

    private var coreLovePath: String {
        Bundle.main.path(forResource: "vnds", ofType: "love") ?? ""
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
                        .navigationTitle("SwiftVN")
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
                    .navigationTitle("SwiftVN")
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

#Preview {
    ContentView()
}
