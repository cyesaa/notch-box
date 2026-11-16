import NotchBoxCore
import SwiftUI

/// A code with the ring that runs down until it changes.
struct CodeCountdown: View {
    let account: OTPAccount
    let time: Date
    var size: CGFloat = 16

    var body: some View {
        let period = max(1, account.period)
        let remaining = TOTP.secondsRemaining(at: time, period: period)
        // `time` moves once a second: aim at where the ring is when that second ends, and glide there.
        let left = Double(remaining - 1) / period
        let isNewCode = Double(remaining) >= period
        ZStack {
            Circle()
                .stroke(NotchTheme.track, lineWidth: size / 8)
            Circle()
                .trim(from: 0, to: min(max(left, 0), 1))
                .stroke(
                    remaining <= 5 ? Color(red: 1, green: 0.5, blue: 0.38) : NotchTheme.secondaryText,
                    style: StrokeStyle(lineWidth: size / 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(isNewCode ? .easeOut(duration: 0.25) : .linear(duration: 1), value: left)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The row under the notch while the browser is on a sign-in page of a stored account: who the code is
/// for, the code and how long it lasts. A click copies it. Only this row takes clicks (see
/// `NotchInteraction`); the notch above it still opens the player.
struct AuthHUDView: View {
    let model: NotchViewModel

    var body: some View {
        let auth = model.auth
        VStack(spacing: 0) {
            if model.info != nil {
                CollapsedView(model: model, isInteractive: false)
            } else {
                Color.clear.frame(height: model.notchSize.height)
            }
            if let entry = auth.promptEntry {
                row(entry, auth: auth)
                    .frame(height: NotchLayout.authRowHeight - 8)
                    .padding(.horizontal, 8)
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ entry: AuthEntry, auth: AuthModel) -> some View {
        let isCopied = auth.copiedID == entry.id
        let code = entry.account.code(at: auth.time)
        return HStack(spacing: 2) {
            if auth.promptAccountIDs.count > 1 {
                Button(action: auth.showNextPromptAccount) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchTheme.secondaryText)
                        .frame(width: 26, height: NotchLayout.authRowHeight - 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(L10n.authNextAccount)
                .accessibilityLabel(L10n.authNextAccount)
            }
            Button { auth.copyCode(of: entry) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isCopied ? L10n.authCopied : entry.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchTheme.primaryText)
                            .truncationMode(.tail)
                        if !entry.subtitle.isEmpty, !isCopied {
                            Text(entry.subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(NotchTheme.secondaryText)
                                .truncationMode(.middle)
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(TOTP.spaced(code))
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(NotchTheme.primaryText)
                        .contentTransition(.numericText())
                        .fixedSize()
                    CodeCountdown(account: entry.account, time: auth.time, size: 16)
                }
                .padding(.leading, auth.promptAccountIDs.count > 1 ? 2 : 10)
                .padding(.trailing, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help(L10n.authCopy)
            .accessibilityLabel("\(entry.title) \(code)")
            .accessibilityHint(L10n.authCopy)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCopied ? Color.white.opacity(0.16) : NotchTheme.tile)
        )
        .contextMenu {
            Button(L10n.authCopy) { auth.copyCode(of: entry) }
            if auth.promptAccountIDs.count > 1 { Button(L10n.authNextAccount, action: auth.showNextPromptAccount) }
            Button(L10n.authHide, action: auth.dismissPrompt)
        }
        .animation(.easeOut(duration: 0.15), value: isCopied)
        .animation(.easeOut(duration: 0.2), value: code)
    }
}

/// The codes column of the open player: every stored account with its code, the ones for the page in
/// the browser first. Clicking a row copies its code; the pin makes an account the one for that site.
struct AuthView: View {
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
            Image(systemName: NotchWidget.auth.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.authTitle)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            Button(action: model.auth.openManager) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help(L10n.authManage)
            .accessibilityLabel(L10n.authManage)
        }
        .foregroundStyle(NotchTheme.secondaryText)
    }

    @ViewBuilder
    private var content: some View {
        let auth = model.auth
        if auth.storage == .unreadable {
            message(L10n.authUnreadable, button: L10n.authRetry) { auth.reload() }
        } else if auth.entries.isEmpty {
            message(L10n.authEmpty, button: L10n.authImportShort, action: auth.openManager)
        } else if isRenderingSnapshot {
            // ImageRenderer draws scroll views blank.
            rows(auth).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ScrollView(.vertical, showsIndicators: false) { rows(auth) }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func rows(_ auth: AuthModel) -> some View {
        VStack(spacing: 4) {
            ForEach(auth.listedEntries) { entry in
                AuthRow(
                    entry: entry,
                    time: auth.time,
                    isCopied: auth.copiedID == entry.id,
                    isForSite: auth.siteAccountIDs.contains(entry.id),
                    site: auth.activeSite,
                    isPinned: auth.isPinned(entry),
                    onCopy: { auth.copyCode(of: entry) },
                    onTogglePin: { auth.togglePin(entry) }
                )
            }
        }
    }

    private func message(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(NotchTheme.detailFont)
                .foregroundStyle(NotchTheme.tertiaryText)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(button)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(NotchTheme.primaryText)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One account: click it to copy its code. With a browser in front, the pin makes it the account whose
/// code shows on that site.
private struct AuthRow: View {
    let entry: AuthEntry
    let time: Date
    let isCopied: Bool
    /// The page in the browser belongs to this account.
    let isForSite: Bool
    let site: String?
    let isPinned: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void

    static let height: CGFloat = 36

    var body: some View {
        let code = entry.account.code(at: time)
        HStack(spacing: 2) {
            Button(action: onCopy) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isCopied ? L10n.authCopied : entry.title)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(NotchTheme.primaryText)
                            .truncationMode(.tail)
                        if !entry.subtitle.isEmpty, !isCopied {
                            Text(entry.subtitle)
                                .font(.system(size: 9.5))
                                .foregroundStyle(NotchTheme.secondaryText)
                                .truncationMode(.middle)
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(TOTP.spaced(code))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(NotchTheme.primaryText)
                        .contentTransition(.numericText())
                        .fixedSize()
                    CodeCountdown(account: entry.account, time: time, size: 12)
                }
                .padding(.leading, 8)
                .padding(.trailing, site == nil ? 8 : 2)
                .frame(height: Self.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help(L10n.authCopy)
            .accessibilityLabel("\(entry.title) \(code)")
            .accessibilityHint(L10n.authCopy)
            if let site {
                RowButton(symbol: isPinned ? "pin.fill" : "pin", label: pinLabel(site), isActive: isPinned, action: onTogglePin)
                    .padding(.trailing, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCopied || isForSite ? Color.white.opacity(0.16) : NotchTheme.tile)
        )
        .contextMenu {
            Button(L10n.authCopy, action: onCopy)
            if let site { Button(pinLabel(site), action: onTogglePin) }
        }
        .animation(.easeOut(duration: 0.15), value: isCopied)
        .animation(.easeOut(duration: 0.2), value: code)
    }

    private func pinLabel(_ site: String) -> String {
        isPinned ? L10n.authUnpin(site) : L10n.authPin(site)
    }
}
