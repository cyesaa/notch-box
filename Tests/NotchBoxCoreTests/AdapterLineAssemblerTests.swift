import Foundation
import Testing
@testable import NotchBoxCore

struct AdapterLineAssemblerTests {
    func bytes(_ text: String) -> Data { Data(text.utf8) }

    @Test func splitsAChunkIntoLines() {
        var assembler = AdapterLineAssembler()
        let output = assembler.append(bytes("a\nb\n"))
        #expect(output.lines == ["a", "b"])
        #expect(!output.discardedOverlongLine)
    }

    @Test func keepsAPartialLineUntilItsNewlineArrives() {
        var assembler = AdapterLineAssembler()
        #expect(assembler.append(bytes("ab")).lines == [])
        #expect(assembler.append(bytes("c\nd")).lines == ["abc"])
        #expect(assembler.append(bytes("\n")).lines == ["d"])
    }

    @Test func returnsEmptyLines() {
        var assembler = AdapterLineAssembler()
        #expect(assembler.append(bytes("a\n\nb\n")).lines == ["a", "", "b"])
    }

    @Test func joinsAMultibyteCharacterSplitAcrossChunks() {
        var assembler = AdapterLineAssembler()
        let letter = bytes("ş")
        #expect(assembler.append(letter.prefix(1)).lines == [])
        #expect(assembler.append(letter.dropFirst() + bytes("\n")).lines == ["ş"])
    }

    @Test func dropsLinesThatAreNotUTF8() {
        var assembler = AdapterLineAssembler()
        #expect(assembler.append(Data([0xFF, 0x0A]) + bytes("ok\n")).lines == ["ok"])
    }

    @Test func defaultCapIsEightMegabytes() {
        #expect(AdapterLineAssembler.defaultMaxLineBytes == 8 * 1024 * 1024)
        #expect(AdapterLineAssembler().maxLineBytes == 8 * 1024 * 1024)
    }

    @Test func partialLineAtTheCapIsKept() {
        var assembler = AdapterLineAssembler(maxLineBytes: 4)
        #expect(!assembler.append(bytes("abcd")).discardedOverlongLine)
        #expect(assembler.append(bytes("\n")).lines == ["abcd"])
    }

    @Test func partialLineOverTheCapIsDiscarded() {
        var assembler = AdapterLineAssembler(maxLineBytes: 4)
        let output = assembler.append(bytes("abcde"))
        #expect(output.lines == [])
        #expect(output.discardedOverlongLine)
        // The rest of the discarded line arrives as its own (garbage) line, then the stream recovers.
        #expect(assembler.append(bytes("f\nok\n")).lines == ["f", "ok"])
    }

    @Test func completeLinesAreSplitOffBeforeTheCapIsChecked() {
        var assembler = AdapterLineAssembler(maxLineBytes: 4)
        let output = assembler.append(bytes("abcdefgh\nij"))
        #expect(output.lines == ["abcdefgh"])
        #expect(!output.discardedOverlongLine)
        #expect(assembler.append(bytes("\n")).lines == ["ij"])
    }

    @Test func capCountsOnlyTheBytesLeftAfterTheLastNewline() {
        var assembler = AdapterLineAssembler(maxLineBytes: 4)
        let output = assembler.append(bytes("ab\ncdefg"))
        #expect(output.lines == ["ab"])
        #expect(output.discardedOverlongLine)
    }

    @Test func resetDropsThePartialLine() {
        var assembler = AdapterLineAssembler()
        _ = assembler.append(bytes("stale"))
        assembler.reset()
        #expect(assembler.append(bytes("fresh\n")).lines == ["fresh"])
    }
}
