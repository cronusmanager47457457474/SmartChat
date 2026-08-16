import SwiftUI

struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks.indices, id: \.self) { index in
                switch blocks[index] {
                case .code(let code):
                    codeBlock(code)
                case .markdown(let markdown):
                    Text(mdAttributed(markdown))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Block {
        case code(String)
        case markdown(String)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var inCode = false
        var codeLines: [String] = []
        var markdownLines: [String] = []

        func flushCode() {
            if !codeLines.isEmpty {
                result.append(.code(codeLines.joined(separator: "\n")))
                codeLines = []
            }
        }
        func flushMarkdown() {
            let joined = markdownLines.joined(separator: "\n")
            if !joined.isEmpty {
                result.append(.markdown(joined))
            }
            markdownLines = []
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    flushCode()
                    inCode = false
                } else {
                    flushMarkdown()
                    inCode = true
                }
            } else if inCode {
                codeLines.append(line)
            } else {
                markdownLines.append(line)
            }
        }
        if inCode {
            flushCode()
        } else {
            flushMarkdown()
        }
        return result
    }

    private func mdAttributed(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: string, options: options) {
            return attributed
        }
        return AttributedString(string)
    }

    private func codeBlock(_ code: String) -> some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}