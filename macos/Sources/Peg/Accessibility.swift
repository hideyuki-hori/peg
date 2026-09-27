import ApplicationServices

enum Accessibility {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        var keyCallbacks = kCFTypeDictionaryKeyCallBacks
        var valueCallbacks = kCFTypeDictionaryValueCallBacks
        guard let options = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &keyCallbacks, &valueCallbacks) else {
            return AXIsProcessTrusted()
        }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        CFDictionarySetValue(
            options,
            Unmanaged.passUnretained(key).toOpaque(),
            Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        )
        return AXIsProcessTrustedWithOptions(options)
    }
}
