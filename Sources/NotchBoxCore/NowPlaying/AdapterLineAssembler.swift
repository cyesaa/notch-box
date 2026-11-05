import Foundation

/// Turns the adapter's stdout chunks into lines. Chunks can end anywhere, even inside a UTF-8 character.
public struct AdapterLineAssembler: Sendable {
    /// A single adapter line is far smaller; beyond this without a newline the stream is garbage.
    public static let defaultMaxLineBytes = 8 * 1024 * 1024

    public struct Output: Equatable, Sendable {
        /// Complete lines without their newline. Lines that are not valid UTF-8 are left out.
        public var lines: [String]
        /// The unfinished line grew past `maxLineBytes` and was thrown away.
        public var discardedOverlongLine: Bool
    }

    public let maxLineBytes: Int
    private var buffer = Data()

    public init(maxLineBytes: Int = AdapterLineAssembler.defaultMaxLineBytes) {
        self.maxLineBytes = maxLineBytes
    }

    public mutating func append(_ data: Data) -> Output {
        buffer.append(data)
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        let overflowed = buffer.count > maxLineBytes
        if overflowed {
            buffer.removeAll()
        }
        return Output(lines: lines, discardedOverlongLine: overflowed)
    }

    /// Drops the unfinished line, e.g. when a new adapter process starts.
    public mutating func reset() {
        buffer.removeAll()
    }
}
