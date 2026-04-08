import SwiftUI
import SwiftTerm

struct EmbeddedTerminalView: NSViewRepresentable {
    @Environment(TerminalSessionService.self) private var sessionService
    let tab: ActiveTab
    let isActive: Bool

    func makeNSView(context: Context) -> NSView {
        let termView = sessionService.getOrCreateTerminal(for: tab)
        termView.translatesAutoresizingMaskIntoConstraints = false
        // Use a container to handle layout
        let container = NSView(frame: .zero)
        container.addSubview(termView)
        NSLayoutConstraint.activate([
            termView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            termView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            termView.topAnchor.constraint(equalTo: container.topAnchor),
            termView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isActive {
            // Give keyboard focus to the terminal
            DispatchQueue.main.async {
                if let termView = nsView.subviews.first {
                    nsView.window?.makeFirstResponder(termView)
                }
            }
        }
    }
}
