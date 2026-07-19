//
//  ContentView.swift
//  SwiftHeart
//

import SwiftUI

// MARK: - LoveGameView

/// A SwiftUI view that hosts a `LoveViewController` full-screen.
/// When Love2D exits (love.event.quit without restart) the `onQuit` closure
/// is called so the parent can pop back to the main menu.
struct LoveGameView: UIViewControllerRepresentable {
    let gamePath: String
    /// Extra command-line arguments forwarded to Love2D after the game path.
    var extraArgs: [String] = []
    let onQuit: () -> Void

    func makeUIViewController(context: Context) -> LoveViewController {
        LoveViewController(gamePath: gamePath, extraArgs: extraArgs, onQuit: onQuit)
    }

    func updateUIViewController(_ uiViewController: LoveViewController,
                                context: Context) {}
}

// MARK: - ContentView

struct ContentView: View {
    /// When `true` the Love2D game is shown; when `false` the main menu is shown.
    @State private var isPlayingGame = false

    /// Path to `core.love` inside the app's Documents directory.
    private var coreLovePath: String {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("core.love").path
    }

    var body: some View {
        if isPlayingGame {
            LoveGameView(gamePath: coreLovePath, extraArgs: [], onQuit: {
                // Called on the main thread when love.event.quit fires
                // (without restart).
                isPlayingGame = false
            })
            .ignoresSafeArea()
        } else {
            mainMenu
        }
    }

    // MARK: Main menu

    private var mainMenu: some View {
        VStack(spacing: 24) {
            Text("SwiftHeart")
                .font(.largeTitle)
                .bold()

            Button {
                isPlayingGame = true
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.title2)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!FileManager.default.fileExists(atPath: coreLovePath))

            if !FileManager.default.fileExists(atPath: coreLovePath) {
                Text("Place core.love in the app's Documents folder to play.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

#Preview {
    ContentView()
}
