import SwiftUI

struct HeaderView: View {
    @Environment(\.theme) var theme
    @Environment(\.scaleFactor) var scale
    @State private var currentTime = Date()
    @Binding var showSettings: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack {
            HStack(spacing: 6 * scale) {
                Image(systemName: "terminal")
                    .foregroundColor(theme.primary)
                    .font(.system(size: 14 * scale))
                GradientShiftText(
                    text: "[SYS.MONITOR.v4.LND]",
                    font: AppTheme.headlineFont(size: 10 * scale),
                    tracking: 3 * scale
                )
                .textCase(.uppercase)
            }

            Spacer()

            HStack(spacing: 16 * scale) {
                Text("\(NSUserName())-JARVIS")
                    .font(AppTheme.labelFont(size: 8 * scale))
                    .tracking(2 * scale)
                    .textCase(.uppercase)
                    .foregroundColor(theme.onSurfaceVariant)

                Text(timeFormatter.string(from: currentTime))
                    .font(AppTheme.labelFont(size: 8 * scale))
                    .tracking(2 * scale)
                    .foregroundColor(theme.primary)
                    .onReceive(timer) { currentTime = $0 }

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(theme.primary)
                        .font(.system(size: 12 * scale))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12 * scale)
        .frame(height: 40 * scale)
        .background(theme.surfaceContainerHigh.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.primary.opacity(0.2)).frame(height: 1)
        }
    }
}
