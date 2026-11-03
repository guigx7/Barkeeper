import CoreGraphics
import Darwin

/// Private SkyLight/CGS calls, resolved at runtime with dlsym so a missing symbol degrades
/// gracefully instead of crashing at launch. Keep every private API in this file.
enum PrivateCGS {
    typealias ConnectionID = Int32

    private typealias MainConnectionFn = @convention(c) () -> ConnectionID
    private typealias WindowCountFn = @convention(c) (ConnectionID, ConnectionID, UnsafeMutablePointer<Int32>) -> CGError
    private typealias MenuBarListFn = @convention(c) (ConnectionID, ConnectionID, Int32, UnsafeMutablePointer<CGWindowID>, UnsafeMutablePointer<Int32>) -> CGError

    nonisolated(unsafe) private static let handle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, as: T.Type) -> T? {
        guard let sym = dlsym(handle ?? UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    private static let mainConnection = symbol("CGSMainConnectionID", as: MainConnectionFn.self)
    private static let windowCount = symbol("CGSGetWindowCount", as: WindowCountFn.self)
    private static let menuBarList = symbol("CGSGetProcessMenuBarWindowList", as: MenuBarListFn.self)

    static var isAvailable: Bool { mainConnection != nil && windowCount != nil && menuBarList != nil }

    /// All menu bar item windows of every process (target connection 0 = all).
    static func menuBarWindowList() -> [CGWindowID]? {
        guard let mainConnection, let windowCount, let menuBarList else { return nil }
        let cid = mainConnection()
        var count: Int32 = 0
        guard windowCount(cid, 0, &count) == .success else { return nil }
        // The reported count can lag behind new windows; leave headroom.
        count = max(count, 0) + 256
        var ids = [CGWindowID](repeating: 0, count: Int(count))
        var real: Int32 = 0
        guard menuBarList(cid, 0, count, &ids, &real) == .success else { return nil }
        return Array(ids.prefix(Int(real)))
    }
}
