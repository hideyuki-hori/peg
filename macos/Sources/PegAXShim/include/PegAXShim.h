#ifndef PegAXShim_h
#define PegAXShim_h

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>
#include <stddef.h>

AXUIElementRef PegAXCopyMenuBar(pid_t pid, float timeout) CF_RETURNS_RETAINED;
CFArrayRef PegAXCopyChildren(AXUIElementRef element) CF_RETURNS_RETAINED;
AXUIElementRef PegAXCopyElementAt(CFArrayRef array, CFIndex index) CF_RETURNS_RETAINED;
bool PegAXCopyTitle(AXUIElementRef element, char *buffer, size_t size);
bool PegAXCopyRole(AXUIElementRef element, char *buffer, size_t size);
bool PegAXIsEnabled(AXUIElementRef element);
bool PegAXPress(AXUIElementRef element);

#endif
