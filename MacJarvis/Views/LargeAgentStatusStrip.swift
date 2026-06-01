import SwiftUI

struct LargeAgentStatusStrip: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let snapshot: LargeAgentSnapshot
    var now: Date = Date()

    var body: some View {
        let color = snapshot.severity.color(theme: theme)

        HStack(spacing: 12 * scale) {
            Rectangle()
                .fill(color)
                .frame(width: 4 * scale)
                .neonGlow(color: color, radius: 8 * scale)

            VStack(alignment: .leading, spacing: 4 * scale) {
                HStack(spacing: 8 * scale) {
                    Text(snapshot.displayName.uppercased())
                        .font(AppTheme.headlineFont(size: 15 * scale))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(snapshot.status.label)
                        .font(AppTheme.labelFont(size: 9 * scale))
                        .foregroundColor(color)
                        .padding(.horizontal, 6 * scale)
                        .padding(.vertical, 2 * scale)
                        .overlay {
                            Rectangle().stroke(color.opacity(0.6), lineWidth: 1)
                        }
                }

                Text(snapshot.statusLine)
                    .font(AppTheme.bodyFont(size: 9 * scale))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8 * scale)

            VStack(alignment: .trailing, spacing: 4 * scale) {
                Text("SIGNAL \(snapshot.ageText(now: now))")
                    .font(AppTheme.monoFont(size: 8 * scale))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6 * scale) {
                    Text(snapshot.tokenSummary?.formattedTokens ?? "--")
                    Text(snapshot.tokenSummary?.formattedCost ?? "--")
                }
                .font(AppTheme.labelFont(size: 12 * scale))
                .foregroundColor(theme.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 110 * scale, alignment: .trailing)
        }
        .padding(.vertical, 10 * scale)
        .padding(.trailing, 12 * scale)
        .background(theme.surfaceContainer.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(color.opacity(0.25)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.displayName), \(snapshot.status.accessibilityPhrase), signal age \(snapshot.ageText(now: now))")
        .accessibilityIdentifier("largeAgentStatus-\(snapshot.kind.rawValue)")
    }
}
