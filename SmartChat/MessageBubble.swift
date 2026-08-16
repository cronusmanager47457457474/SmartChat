import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser {
                Spacer(minLength: 48)
                bubble
            } else {
                bubble
                Spacer(minLength: 48)
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let data = message.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if message.isUser {
                Text(message.content.isEmpty ? "Image" : message.content)
                    .textSelection(.enabled)
            } else if let error = message.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else {
                MarkdownText(message.content)
            }
        }
        .padding(12)
        .background(
            message.isUser
                ? Color.accentColor.opacity(0.18)
                : Color(.secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}