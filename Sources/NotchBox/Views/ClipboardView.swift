import NotchBoxCore
import SwiftUI

/// The clipboard column of the open player: the last things the user copied, newest first. Clicking
/// one puts it back on the pasteboard; each row can be removed, and an image can be viewed large.
struct ClipboardView: View {
    let model: NotchViewModel
    @Environment(\.isRenderingSnapshot) private var isRenderingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: model.notchSize.height)
                .padding(.bottom, 4)
            content
                // minHeight 0: a long list scrolls instead of making the panel taller.
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        }
    }

    /// Sits in the band beside the camera.
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.clipboardTitle)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            if !model.clipboard.recent.isEmpty {
                Button(action: model.clearClipboard) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(L10n.clipboardClear)
                .accessibilityLabel(L10n.clipboardClear)
            }
        }
        .foregroundStyle(NotchTheme.secondaryText)
    }

    @ViewBuilder
    private var content: some View {
        if model.clipboard.items.isEmpty {
            Text(model.isClipboardDenied ? L10n.clipboardDenied : L10n.clipboardEmpty)
                .font(NotchTheme.detailFont)
                .foregroundStyle(NotchTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isRenderingSnapshot {
            // ImageRenderer draws scroll views blank.
            rows.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ScrollView(.vertical, showsIndicators: false) { rows }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    /// Pinned items first, a hairline, then the recent ones.
    private var rows: some View {
        VStack(spacing: 4) {
            ForEach(model.clipboard.pinned) { row($0) }
            if !model.clipboard.pinned.isEmpty, !model.clipboard.recent.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            ForEach(model.clipboard.recent) { row($0) }
        }
    }

    private func row(_ item: ClipboardItem) -> some View {
        ClipboardRow(
            item: item,
            thumbnail: model.thumbnail(for: item),
            isCopied: model.recentlyCopiedID == item.id,
            isPreviewed: model.previewedClipboardItem?.id == item.id,
            canPin: item.isPinned || model.clipboard.canPin,
            onCopy: { model.copyAgain(item) },
            onPreview: { model.preview(item) },
            onTogglePin: { model.togglePin(item) },
            onRemove: { model.removeFromClipboard(item) }
        )
    }
}

/// One copied item: click it to copy it again; the eye shows an image large, the pin keeps it on top
/// (and across restarts), the cross removes it.
private struct ClipboardRow: View {
    let item: ClipboardItem
    let thumbnail: ClipboardThumbnails.Thumbnail?
    let isCopied: Bool
    let isPreviewed: Bool
    /// False when the pins are full (unpinning is always possible).
    let canPin: Bool
    let onCopy: () -> Void
    let onPreview: () -> Void
    let onTogglePin: () -> Void
    let onRemove: () -> Void

    static let height: CGFloat = 32

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onCopy) {
                HStack(spacing: 8) {
                    leading
                        .frame(width: 22, height: 22)
                    Text(isCopied ? L10n.clipboardCopied : label)
                        .font(.system(size: 11.5))
                        .foregroundStyle(isCopied ? NotchTheme.primaryText : NotchTheme.primaryText.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 6)
                .frame(height: Self.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help(L10n.clipboardCopy)
            .accessibilityLabel(label)
            .accessibilityHint(L10n.clipboardCopy)
            if isImage {
                RowButton(symbol: isPreviewed ? "eye.fill" : "eye", label: L10n.clipboardView, action: onPreview)
            }
            RowButton(
                symbol: item.isPinned ? "pin.fill" : "pin",
                label: pinLabel,
                isActive: item.isPinned,
                action: onTogglePin
            )
            .disabled(!canPin)
            .opacity(canPin ? 1 : 0.35)
            RowButton(symbol: "xmark", label: L10n.clipboardRemove, action: onRemove)
        }
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCopied || isPreviewed ? Color.white.opacity(0.16) : NotchTheme.tile)
        )
        .contextMenu {
            Button(L10n.clipboardCopy, action: onCopy)
            if isImage { Button(L10n.clipboardView, action: onPreview) }
            Button(pinLabel, action: onTogglePin).disabled(!canPin)
            Button(L10n.clipboardRemove, role: .destructive, action: onRemove)
        }
        .animation(.easeOut(duration: 0.15), value: isCopied)
    }

    @ViewBuilder
    private var leading: some View {
        if isCopied {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NotchTheme.primaryText)
        } else if let thumbnail {
            Image(nsImage: thumbnail.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(systemName: isImage ? "photo" : "text.alignleft")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchTheme.secondaryText)
        }
    }

    private var isImage: Bool {
        if case .image = item.content { return true }
        return false
    }

    private var pinLabel: String {
        if item.isPinned { return L10n.clipboardUnpin }
        return canPin ? L10n.clipboardPin : L10n.clipboardPinsFull
    }

    private var label: String {
        switch item.content {
        case .text(let text):
            return ClipboardReading.preview(of: text)
        case .image:
            // The thumbnail already says it is an image; the size is what tells images apart.
            guard let size = thumbnail?.pixelSize else { return L10n.clipboardImage }
            return "\(Int(size.width)) × \(Int(size.height))"
        }
    }
}

/// A small icon button at the end of a clipboard row.
private struct RowButton: View {
    let symbol: String
    let label: String
    /// Drawn brighter (a pinned item's pin).
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? NotchTheme.primaryText : NotchTheme.secondaryText)
                .frame(width: 20, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

/// A clipboard image shown large in place of the player: its size and buttons in the band beside the
/// notch, the image below.
struct ClipboardPreviewView: View {
    let model: NotchViewModel
    let item: ClipboardItem

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let size = model.thumbnail(for: item)?.pixelSize {
                    Text(verbatim: "\(Int(size.width)) × \(Int(size.height))")
                        .font(NotchTheme.timeFont)
                        .foregroundStyle(NotchTheme.secondaryText)
                }
                Spacer(minLength: 0)
                RowButton(symbol: "doc.on.doc", label: L10n.clipboardCopy) { model.copyAgain(item) }
                RowButton(symbol: "xmark", label: L10n.clipboardClosePreview, action: model.closePreview)
            }
            .frame(height: model.notchSize.height)
            if let image = model.previewImage(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(L10n.clipboardImage)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(NotchTheme.tertiaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }
}

private struct RenderingSnapshotKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside `SnapshotRenderer`, for views that ImageRenderer cannot draw as they are.
    var isRenderingSnapshot: Bool {
        get { self[RenderingSnapshotKey.self] }
        set { self[RenderingSnapshotKey.self] = newValue }
    }
}
