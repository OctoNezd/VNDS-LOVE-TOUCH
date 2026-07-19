//
//  InGameSlotSheet.swift
//  SwiftHeart
//
//  Presented while a game is running (triggered by Lua via InGameSlotCoordinator).
//  For "save" mode: all 30 slots are selectable (empty slots can be overwritten).
//  For "load" mode: only existing slots are selectable.
//

import SwiftUI

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