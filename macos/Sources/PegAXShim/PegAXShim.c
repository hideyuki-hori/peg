#include "PegAXShim.h"

static float sharedTimeout = 0.5f;

static CFTypeRef copyAttribute(AXUIElementRef element, CFStringRef name) {
    CFTypeRef value = NULL;
    if (AXUIElementCopyAttributeValue(element, name, &value) != kAXErrorSuccess) {
        return NULL;
    }
    return value;
}

static bool copyString(AXUIElementRef element, CFStringRef name, char *buffer, size_t size) {
    CFTypeRef value = copyAttribute(element, name);
    if (value == NULL) {
        return false;
    }
    bool ok = false;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        ok = CFStringGetCString(value, buffer, (CFIndex)size, kCFStringEncodingUTF8);
    }
    CFRelease(value);
    return ok;
}

AXUIElementRef PegAXCopyMenuBar(pid_t pid, float timeout) {
    sharedTimeout = timeout;
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    if (app == NULL) {
        return NULL;
    }
    AXUIElementSetMessagingTimeout(app, timeout);
    CFTypeRef bar = copyAttribute(app, kAXMenuBarAttribute);
    CFRelease(app);
    if (bar == NULL) {
        return NULL;
    }
    if (CFGetTypeID(bar) != AXUIElementGetTypeID()) {
        CFRelease(bar);
        return NULL;
    }
    AXUIElementSetMessagingTimeout((AXUIElementRef)bar, timeout);
    return (AXUIElementRef)bar;
}

CFArrayRef PegAXCopyChildren(AXUIElementRef element) {
    CFTypeRef value = copyAttribute(element, kAXChildrenAttribute);
    if (value == NULL) {
        return NULL;
    }
    if (CFGetTypeID(value) != CFArrayGetTypeID()) {
        CFRelease(value);
        return NULL;
    }
    return (CFArrayRef)value;
}

AXUIElementRef PegAXCopyElementAt(CFArrayRef array, CFIndex index) {
    if (array == NULL || index < 0 || index >= CFArrayGetCount(array)) {
        return NULL;
    }
    const void *value = CFArrayGetValueAtIndex(array, index);
    if (value == NULL || CFGetTypeID(value) != AXUIElementGetTypeID()) {
        return NULL;
    }
    AXUIElementRef element = (AXUIElementRef)CFRetain(value);
    AXUIElementSetMessagingTimeout(element, sharedTimeout);
    return element;
}

bool PegAXCopyTitle(AXUIElementRef element, char *buffer, size_t size) {
    return copyString(element, kAXTitleAttribute, buffer, size);
}

bool PegAXCopyRole(AXUIElementRef element, char *buffer, size_t size) {
    return copyString(element, kAXRoleAttribute, buffer, size);
}

bool PegAXIsEnabled(AXUIElementRef element) {
    CFTypeRef value = copyAttribute(element, kAXEnabledAttribute);
    if (value == NULL) {
        return true;
    }
    bool enabled = true;
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        enabled = CFBooleanGetValue(value);
    }
    CFRelease(value);
    return enabled;
}

bool PegAXPress(AXUIElementRef element) {
    return AXUIElementPerformAction(element, kAXPressAction) == kAXErrorSuccess;
}
