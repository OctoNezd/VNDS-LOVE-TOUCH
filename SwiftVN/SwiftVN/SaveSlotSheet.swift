//
//  SaveSlotSheet.swift
//  SwiftVN
//

import SwiftUI

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