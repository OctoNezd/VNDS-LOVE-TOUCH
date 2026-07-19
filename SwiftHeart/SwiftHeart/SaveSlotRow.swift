//
//  SaveSlotRow.swift
//  SwiftHeart
//

import SwiftUI

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