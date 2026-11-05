import Foundation

@MainActor
protocol VolumeControlling: AnyObject {
    /// 0...1
    var volume: Float { get }
    var isSettable: Bool { get }
    var onChange: (() -> Void)? { get set }
    func start()
    func setVolume(_ value: Float)
}

@MainActor
protocol MediaKeySending: AnyObject {
    /// An NX_KEYTYPE_* code from `MediaKeyCode`.
    func send(code: Int32)
}
