import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Captures images of menu bar item windows, including off-screen (hidden) ones.
///
/// Backends, in order:
/// - WindowServer hardware capture (private, see `PrivateCGS.captureWindow`): works off screen.
/// - CoreGraphics window capture (`CGWindowListCreateImageFromArray`), resolved at runtime because it
///   is deprecated in the SDK. One synchronous call for many windows, works for off-screen windows.
/// - ScreenCaptureKit (`SCScreenshotManager`), used when the CG call is missing or returns nothing.
enum ScreenCapture {
    private typealias CreateImageFromArrayFn = @convention(c) (CGRect, CFArray, CGWindowImageOption) -> Unmanaged<CGImage>?

    private static let createImageFromArray: CreateImageFromArrayFn? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImageFromArray") else { return nil }
        return unsafeBitCast(sym, to: CreateImageFromArrayFn.self)
    }()

    private typealias CreateImageFn = @convention(c) (CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption) -> Unmanaged<CGImage>?

    private static let createImage: CreateImageFn? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(sym, to: CreateImageFn.self)
    }()

    /// Image of everything on screen inside `rect` (CG global coordinates).
    nonisolated static func screenImage(rect: CGRect) -> CGImage? {
        createImage?(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])?.takeRetainedValue()
    }

    /// Image of a single window at its native resolution, or nil.
    nonisolated static func cgImage(windowID: CGWindowID) -> CGImage? {
        guard let fn = createImageFromArray else { return nil }
        let image = fn(.null, WindowServer.windowIDArray([windowID]), [.boundsIgnoreFraming, .bestResolution])?.takeRetainedValue()
        guard let image, image.width > 1, image.height > 1 else { return nil }
        return image
    }

    /// Images for many windows. Falls back to ScreenCaptureKit for windows CG could not capture.
    static func images(windowIDs: [CGWindowID]) async -> [CGWindowID: CGImage] {
        var result: [CGWindowID: CGImage] = [:]
        let started = Date()
        var hw = 0, cg = 0
        for id in windowIDs {
            if let image = cgImage(windowID: id) {
                result[id] = image; cg += 1
            } else if let image = PrivateCGS.captureWindow(id) {
                result[id] = image; hw += 1
            }
        }
        Log.platform.info("Capture backends: hw=\(hw) cg=\(cg) (cg symbol \(createImageFromArray != nil))")
        let missing = windowIDs.filter { result[$0] == nil }
        if !missing.isEmpty {
            for (id, image) in await sckImages(windowIDs: missing) { result[id] = image }
        }
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        Log.platform.info("Captured \(result.count)/\(windowIDs.count) item images in \(ms) ms (SCK for \(missing.count))")
        return result
    }

    private static func sckImages(windowIDs: [CGWindowID]) async -> [CGWindowID: CGImage] {
        guard CGPreflightScreenCaptureAccess() else { return [:] }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let wanted = Set(windowIDs)
            var result: [CGWindowID: CGImage] = [:]
            let found = content.windows.filter { wanted.contains($0.windowID) }
            Log.platform.info("SCK sees \(found.count)/\(wanted.count): \(found.map { "\($0.windowID)@\(Int($0.frame.minX)) on=\($0.isOnScreen)" }.joined(separator: " "), privacy: .public)")
            for window in found {
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                let scale = CGFloat(filter.pointPixelScale)
                config.width = Int(window.frame.width * scale)
                config.height = Int(window.frame.height * scale)
                config.showsCursor = false
                config.ignoreShadowsSingleWindow = true
                do {
                    result[window.windowID] = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                } catch {
                    Log.platform.info("SCK capture \(window.windowID) failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            return result
        } catch {
            Log.platform.error("ScreenCaptureKit failed: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }
}
