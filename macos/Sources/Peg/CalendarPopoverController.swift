import AppKit
import SwiftUI

final class CalendarPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class CalendarPopoverController: NSObject, NSWindowDelegate {
    private let model = CalendarModel()
    private let panel: CalendarPanel
    private var anchor = NSRect.zero
    private var anchorWindow: NSWindow?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    override init() {
        panel = CalendarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 356, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        let view = CalendarPopoverView(model: model) { [weak self] size in
            self?.resize(to: size)
        }
        let hosting = NSHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        model.onClose = { [weak self] in
            self?.close()
        }
    }

    var isShown: Bool {
        panel.isVisible
    }

    func toggle(relativeTo view: NSView) {
        if panel.isVisible {
            close()
        } else {
            show(relativeTo: view)
        }
    }

    func show(relativeTo view: NSView) {
        guard let window = view.window else { return }
        anchor = window.convertToScreen(view.convert(view.bounds, to: nil))
        anchorWindow = window
        model.start()
        resize(to: panel.contentView?.fittingSize ?? panel.frame.size)
        panel.makeKeyAndOrderFront(nil)
        startMonitors()
    }

    func close() {
        guard panel.isVisible else { return }
        stopMonitors()
        panel.orderOut(nil)
        model.stop()
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let frame = NSRect(x: anchor.maxX - size.width, y: anchor.minY - 6 - size.height, width: size.width, height: size.height)
        panel.setFrame(frame, display: true)
    }

    private func startMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                guard event.window === self.panel, event.keyCode == 53 else { return event }
                self.close()
                return nil
            }
            if event.window !== self.panel, event.window !== self.anchorWindow {
                self.close()
            }
            return event
        }
    }

    private func stopMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }
}

struct CalendarPopoverView: View {
    @ObservedObject var model: CalendarModel
    let onSize: (CGSize) -> Void

    var body: some View {
        CalendarCard(model: model)
            .frame(width: 340)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            onSize(proxy.size)
                        }
                        .onChange(of: proxy.size) { _, size in
                            onSize(size)
                        }
                }
            )
            .preferredColorScheme(.dark)
    }
}
