import CoreGraphics
import Foundation
import Testing
@testable import NotchBoxCore

struct ClipboardHistoryTests {
    let t0 = Date(timeIntervalSince1970: 1_000)

    @Test func keepsTwentyItems() {
        #expect(ClipboardHistory.capacity == 20)
    }

    @Test func newestComesFirst() {
        var history = ClipboardHistory()
        history.record(.text("one"), at: t0)
        history.record(.text("two"), at: t0.addingTimeInterval(1))
        #expect(history.items.map(\.content) == [.text("two"), .text("one")])
    }

    @Test func theOldestFallsOffPastTheCapacity() {
        var history = ClipboardHistory()
        for index in 0..<25 {
            history.record(.text("item \(index)"), at: t0.addingTimeInterval(Double(index)))
        }
        #expect(history.items.count == 20)
        #expect(history.items.first?.content == .text("item 24"))
        #expect(history.items.last?.content == .text("item 5"))
    }

    @Test func copyingTheSameThingAgainMovesItToTheTop() {
        var history = ClipboardHistory()
        history.record(.text("one"), at: t0)
        let firstID = history.items[0].id
        history.record(.text("two"), at: t0.addingTimeInterval(1))
        history.record(.text("one"), at: t0.addingTimeInterval(2))
        #expect(history.items.map(\.content) == [.text("one"), .text("two")])
        #expect(history.items[0].id == firstID)
        #expect(history.items[0].copiedAt == t0.addingTimeInterval(2))
    }

    @Test func imagesAreComparedByTheirData() {
        var history = ClipboardHistory()
        let png = ClipboardContent.image(Data([1, 2, 3]), type: "public.png")
        history.record(png, at: t0)
        history.record(.text("x"), at: t0)
        history.record(png, at: t0)
        #expect(history.items.count == 2)
        #expect(history.items[0].content == png)
    }

    @Test func idsAreUnique() {
        var history = ClipboardHistory()
        history.record(.text("a"), at: t0)
        history.record(.text("b"), at: t0)
        #expect(history.items[0].id != history.items[1].id)
    }

    @Test func removeAndClear() {
        var history = ClipboardHistory()
        history.record(.text("a"), at: t0)
        history.record(.text("b"), at: t0)
        history.remove(id: history.items[0].id)
        #expect(history.items.map(\.content) == [.text("a")])
        history.clear()
        #expect(history.items.isEmpty)
    }
}

struct ClipboardReadingTests {
    @Test func plainTextIsRecordedAsText() {
        #expect(ClipboardReading.kind(of: ["public.utf8-plain-text", "public.rtf"]) == .text)
    }

    @Test func textWinsOverAnImageOfTheSameSelection() {
        // Numbers, Keynote and others put a picture of the selection next to its text.
        #expect(ClipboardReading.kind(of: ["public.tiff", "public.utf8-plain-text"]) == .text)
    }

    @Test func imagesPreferPNG() {
        #expect(ClipboardReading.kind(of: ["public.tiff", "public.png"]) == .image(type: "public.png"))
        #expect(ClipboardReading.kind(of: ["public.tiff"]) == .image(type: "public.tiff"))
    }

    @Test func passwordManagersAndTransientItemsAreSkipped() {
        for marker in ClipboardReading.privateMarkers {
            #expect(ClipboardReading.kind(of: ["public.utf8-plain-text", marker]) == nil)
        }
        #expect(ClipboardReading.privateMarkers.contains("org.nspasteboard.ConcealedType"))
        #expect(ClipboardReading.privateMarkers.contains("org.nspasteboard.TransientType"))
    }

    @Test func copiedFilesAreSkipped() {
        // Finder puts the file name as text and the file's icon as an image next to the file URL.
        #expect(ClipboardReading.kind(of: ["public.file-url", "public.utf8-plain-text", "public.tiff"]) == nil)
    }

    @Test func otherContentIsSkipped() {
        #expect(ClipboardReading.kind(of: ["com.apple.pasteboard.promised-file-url"]) == nil)
        #expect(ClipboardReading.kind(of: []) == nil)
    }

    @Test func blankTextIsSkipped() {
        #expect(ClipboardReading.content(text: "  \n\t ") == nil)
        #expect(ClipboardReading.content(text: " hi ") == .text(" hi "))
    }

    @Test func hugeImagesAreSkipped() {
        let limit = ClipboardReading.maxImageBytes
        #expect(limit == 25_000_000)
        #expect(ClipboardReading.content(image: Data(count: 10), type: "public.png") == .image(Data(count: 10), type: "public.png"))
        #expect(ClipboardReading.content(image: Data(count: limit + 1), type: "public.png") == nil)
        #expect(ClipboardReading.content(image: Data(), type: "public.png") == nil)
    }

    @Test func previewIsOneTidyLine() {
        #expect(ClipboardReading.preview(of: "  first line\n\n  second\tline  ") == "first line second line")
        let long = String(repeating: "a", count: 300)
        #expect(ClipboardReading.preview(of: long).count == ClipboardReading.previewLength)
    }
}

struct ClipboardLayoutTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func theOpenPlayerGrowsToTheLeftForTheClipboard() {
        #expect(NotchLayout.clipboardWidth == 240)
        #expect(NotchLayout.leadingExtension(for: .expanded) == 240)
        #expect(NotchLayout.leadingExtension(for: .expandedEmpty) == 240)
        #expect(NotchLayout.leadingExtension(for: .video) == 0)
        #expect(NotchLayout.leadingExtension(for: .mini) == 0)
    }

    @Test func thePlayerStaysCentredUnderTheNotch() {
        // Content is shifted left by half the extension, so the player part keeps its place.
        #expect(NotchLayout.horizontalOffset(for: .expanded) == -120)
        #expect(NotchLayout.horizontalOffset(for: .video) == 0)
    }

    @Test func screenRectsFollowTheOffset() throws {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let geometry = try #require(NotchGeometry(
            screenFrame: screen,
            safeAreaTop: 32,
            auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 663.5, height: 32),
            auxiliaryTopRight: CGRect(x: 848.5, y: 950, width: 663.5, height: 32)
        ))
        let size = CGSize(width: 620, height: 186)
        #expect(geometry.panelFrame(for: size, offsetX: -110) == CGRect(x: 756 - 310 - 110, y: 982 - 186, width: 620, height: 186))
        let rect = geometry.screenRect(for: CGRect(x: 10, y: 20, width: 30, height: 40), inContentOf: size, offsetX: -110)
        #expect(rect == CGRect(x: 756 - 310 - 110 + 10, y: 982 - 20 - 40, width: 30, height: 40))
    }
}
