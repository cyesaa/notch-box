import NotchBoxCore
import SwiftUI

/// The clipboard column left of the open player: the last things the user copied, newest first. Clicking
/// one puts it back on the pasteboard; right-clicking removes it.
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
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.bottom, 14)
        .overlay(alignment: .trailing) {
            // A hairline between the clipboard and the player, below the notch band.
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.top, model.notchSize.height + 8)
                .padding(.bottom, 18)
        }
    }

    /// Sits in the band left of the camera.
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.clipboardTitle)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            if !model.clipboard.items.isEmpty {
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

    private var rows: some View {
        VStack(spacing: 4) {
            ForEach(model.clipboard.items) { item in
                ClipboardRow(
                    item: item,
                    thumbnail: model.thumbnail(for: item),
                    isCopied: model.recentlyCopiedID == item.id,
                    onCopy: { model.copyAgain(item) },
                    onRemove: { model.removeFromClipboard(item) }
                )
            }
        }
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let thumbnail: ClipboardThumbnails.Thumbnail?
    let isCopied: Bool
    let onCopy: () -> Void
    let onRemove: () -> Void

    static let height: CGFloat = 32

    var body: some View {
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
            .padding(.horizontal, 6)
            .frame(height: Self.height)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isCopied ? Color.white.opacity(0.16) : NotchTheme.tile)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .help(L10n.clipboardCopy)
        .accessibilityLabel(label)
        .accessibilityHint(L10n.clipboardCopy)
        .contextMenu {
            Button(L10n.clipboardCopy, action: onCopy)
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

    private var label: String {
        switch item.content {
        case .text(let text):
            return ClipboardReading.preview(of: text)
        case .image:
            guard let size = thumbnail?.pixelSize else { return L10n.clipboardImage }
            return "\(L10n.clipboardImage) · \(Int(size.width)) × \(Int(size.height))"
        }
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
