//
//  GameTileView.swift
//  SwiftVN
//
//   ┌──────────────────────────────────────────┐
//   │         background / preview image       │
//   ├──────────────────────────────────────────┤
//   │  [icon]  Title                           │
//   └──────────────────────────────────────────┘
//

import SwiftUI

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