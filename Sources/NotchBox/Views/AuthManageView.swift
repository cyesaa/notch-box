import AVFoundation
import NotchBoxCore
import Observation
import SwiftUI

/// What the accounts window is showing. (A class rather than `@State`: the SwiftUI macros are not in
/// the Command Line Tools this project builds with.)
@MainActor
@Observable
final class AuthManageState {
    /// Non-nil while the camera is open.
    var scan: AuthScanSession?
    var pendingDelete: AuthEntry?
    /// A line under the accounts: what the last import or delete did.
    var note: String?
    var isSaving = false

    func startScanning() {
        note = nil
        let session = AuthScanSession()
        scan = session
        session.start()
    }

    func stopScanning(note: String? = nil) {
        scan?.stop()
        scan = nil
        isSaving = false
        self.note = note
    }
}

/// The accounts window: the stored accounts with a delete button each, and the way in for new ones.
struct AuthManageView: View {
    let auth: AuthModel
    let state: AuthManageState

    var body: some View {
        Group {
            if let scan = state.scan {
                AuthScanView(auth: auth, state: state, session: scan)
            } else {
                accounts
            }
        }
        .frame(width: 460, height: 540)
    }

    private var accounts: some View {
        VStack(spacing: 0) {
            Text(L10n.authWindowIntro)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            Divider()
            if auth.storage == .unreadable {
                unavailable(title: L10n.authUnreadable, text: L10n.authUnreadableHint, symbol: "lock.trianglebadge.exclamationmark") {
                    Button(L10n.authRetry) { auth.reload() }
                }
            } else if auth.entries.isEmpty {
                unavailable(title: L10n.authWindowEmptyTitle, text: L10n.authWindowEmptyText, symbol: "qrcode.viewfinder") {
                    EmptyView()
                }
            } else {
                List(auth.entries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .fontWeight(.medium)
                            if !entry.subtitle.isEmpty {
                                Text(entry.subtitle)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .lineLimit(1)
                        .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Button { state.pendingDelete = entry } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help(L10n.authDelete)
                        .accessibilityLabel(L10n.authDelete)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                if let note = state.note {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button(L10n.authImportButton) { state.startScanning() }
                .buttonStyle(.borderedProminent)
                .disabled(auth.storage == .unreadable)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .alert(
            L10n.authDeleteTitle(state.pendingDelete?.title ?? ""),
            isPresented: Binding(get: { state.pendingDelete != nil }, set: { if !$0 { state.pendingDelete = nil } }),
            presenting: state.pendingDelete
        ) { entry in
            Button(L10n.authDelete, role: .destructive) {
                auth.delete(entry) { deleted in
                    state.note = deleted ? nil : L10n.authSaveFailed
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: { _ in
            Text(L10n.authDeleteText)
        }
    }

    private func unavailable<Actions: View>(title: String, text: String, symbol: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actions()
        }
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One sitting at the camera: what was read so far and what the camera is doing.
@MainActor
@Observable
final class AuthScanSession {
    enum Camera: Equatable {
        case starting
        case running
        case failed(QRScanner.Failure)
    }

    private(set) var found = AuthImport()
    private(set) var camera = Camera.starting
    /// The last QR code in view was not an authenticator's.
    private(set) var sawOtherCode = false
    @ObservationIgnored let scanner = QRScanner()

    func start() {
        scanner.onPayload = { [weak self] payload in self?.read(payload) }
        scanner.start { [weak self] failure in
            self?.camera = failure.map(Camera.failed) ?? .running
        }
    }

    func stop() {
        scanner.onPayload = nil
        scanner.stop()
    }

    private func read(_ payload: String) {
        switch found.add(payload: payload) {
        case .added: sawOtherCode = false
        case .nothingNew: if sawOtherCode { sawOtherCode = false }
        case .notACode: if !sawOtherCode { sawOtherCode = true }
        }
    }
}

/// The camera, the three steps to get the QR code on the phone, and what was read.
struct AuthScanView: View {
    let auth: AuthModel
    let state: AuthManageState
    let session: AuthScanSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.authScanTitle)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 5) {
                step(1, L10n.authScanStep1)
                step(2, L10n.authScanStep2)
                step(3, L10n.authScanStep3)
            }
            camera
                .frame(maxWidth: .infinity)
                .frame(height: 236)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            status
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
            Spacer(minLength: 0)
            HStack {
                Button(L10n.cancel) { state.stopScanning() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.authScanAdd(session.found.accounts.count)) { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(session.found.accounts.isEmpty || state.isSaving)
            }
        }
        .padding(20)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var camera: some View {
        switch session.camera {
        case .starting, .running:
            CameraPreview(session: session.scanner.session, isRunning: session.camera == .running)
                .overlay {
                    if session.camera == .starting { ProgressView().controlSize(.small) }
                }
        case .failed(let failure):
            VStack(spacing: 10) {
                Image(systemName: "video.slash")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Text(failure == .denied ? L10n.authCameraDenied : L10n.authCameraMissing)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if failure == .denied {
                    Button(L10n.authCameraOpenSettings) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.06))
        }
    }

    @ViewBuilder
    private var status: some View {
        let found = session.found
        VStack(alignment: .leading, spacing: 4) {
            if found.accounts.isEmpty {
                Label(session.sawOtherCode ? L10n.authScanNotACode : L10n.authScanLooking, systemImage: session.sawOtherCode ? "exclamationmark.triangle" : "qrcode.viewfinder")
                    .foregroundStyle(.secondary)
                Text(L10n.authScanHint)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(L10n.authScanFound(found.accounts.count), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(found.accounts.map { $0.issuer.isEmpty ? $0.name : $0.issuer }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if found.isWaitingForMore {
                    Text(L10n.authScanMore(found.scannedBatches, found.batchSize))
                        .font(.footnote.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if found.unsupported > 0 {
                Text(L10n.authScanUnsupported(found.unsupported))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .font(.callout)
    }

    private func save() {
        state.isSaving = true
        auth.add(session.found.accounts) { added in
            switch added {
            case nil: state.stopScanning(note: L10n.authSaveFailed)
            case 0: state.stopScanning(note: L10n.authAddedNone)
            case let count?: state.stopScanning(note: L10n.authAdded(count))
            }
        }
    }
}
