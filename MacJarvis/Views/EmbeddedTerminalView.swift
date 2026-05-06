import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    @Environment(TerminalSessionService.self) private var sessionService
    let tab: ActiveTab
    let isActive: Bool

    func makeNSView(context: Context) -> NSView {
        let terminal = sessionService.getOrCreateTerminal(for: tab)
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard isActive, let terminal = nsView.subviews.first as? PseudoTerminalView else { return }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(terminal)
        }
    }
}
