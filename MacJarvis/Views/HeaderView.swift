import SwiftUI

struct HeaderView: View {
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
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .foregroundColor(CyberTheme.primary)
                    .font(.system(size: 14))
                Text("[SYS.MONITOR.v4.LND]")
                    .font(CyberTheme.headlineFont(size: 10))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.primary)
            }

            Spacer()

            HStack(spacing: 16) {
                Text("Neo-Tokyo-01")
                    .font(CyberTheme.labelFont(size: 8))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)

                Text(timeFormatter.string(from: currentTime))
                    .font(CyberTheme.labelFont(size: 8))
                    .tracking(2)
                    .foregroundColor(CyberTheme.primary)
                    .onReceive(timer) { currentTime = $0 }

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(CyberTheme.primary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(CyberTheme.surfaceContainerHigh.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle().fill(CyberTheme.primary.opacity(0.2)).frame(height: 1)
        }
    }
}
