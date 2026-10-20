import ExperienceCore
import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Theme.onPrimary)
            .background(Theme.primary.opacity(isEnabled ? 1 : 0.3), in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.micro, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Theme.text)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.micro, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle { static var primary: PrimaryButtonStyle { .init() } }
extension ButtonStyle where Self == SecondaryButtonStyle { static var secondary: SecondaryButtonStyle { .init() } }

/// Pressable without chrome: scales to 0.97 on press.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.micro, value: configuration.isPressed)
    }
}

// MARK: - Chips

/// Taste chip: hairline border with a category dot; selected = 14% tint + category border.
struct Chip: View {
    let label: String
    var group: CategoryGroup?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let group {
                    Circle().fill(group.color).frame(width: 8, height: 8)
                }
                Text(label).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(Theme.text)
            .background(isOn ? (group?.color ?? Theme.primary).opacity(0.14) : Theme.raised, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isOn ? (group?.color ?? Theme.primary) : Theme.hairline, lineWidth: isOn ? 1.5 : 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > maxWidth {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            let gap = rows[rows.count - 1].indices.isEmpty ? 0 : spacing
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].width += gap + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

// MARK: - Segmented

/// Soft track, white selected segment with lift-sm; selection animates.
struct Segmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    withAnimation(Theme.Motion.short) { selection = value }
                } label: {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(selection == value ? Theme.text : Theme.textMuted)
                        .background {
                            if selection == value {
                                RoundedRectangle(cornerRadius: Theme.Radius.control - 3, style: .continuous)
                                    .fill(Theme.raised)
                                    .liftSmall()
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Provenance

/// The only way to render a `Sourced` value (CLAUDE.md): estimates are labelled "(estimated)".
struct SourcedText: View {
    let value: Sourced<String>

    init(_ value: Sourced<String>) { self.value = value }

    var body: some View {
        if value.needsEstimateLabel {
            Text(value.value) + Text(" (estimated)").foregroundStyle(Theme.textMuted).fontWeight(.regular)
        } else {
            Text(value.value)
        }
    }
}

/// Fact chip on a recommendation card ("$25", "~12 min", "Open till 11").
struct FactChip: View {
    let text: Sourced<String>

    var body: some View {
        SourcedText(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
    }
}

// MARK: - Section header

struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text) }
}
