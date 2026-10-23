import SwiftUI

/// Colored circle with the profile's letter.
struct LetterBadge: View {
    let letter: String
    let color: Color
    var size: CGFloat = 26

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
            .accessibilityHidden(true)
    }
}

/// The Claude icon with a profile badge, as it appears in the Dock.
struct ProfileIconPreview: View {
    let icon: NSImage
    var letter: String?
    var color: Color?
    var size: CGFloat = 96

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
            if let letter, let color {
                LetterBadge(letter: letter, color: color, size: size * 0.42)
                    .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: max(2, size * 0.03)))
                    .offset(x: size * 0.02, y: size * 0.02)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct StatusChip: View {
    let text: String
    var dot: Color?
    var tint: Color?

    var body: some View {
        HStack(spacing: 6) {
            if let dot {
                Circle().fill(dot).frame(width: 7, height: 7).accessibilityHidden(true)
            }
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(tint ?? Color.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill((tint ?? Color.secondary).opacity(0.14)))
    }
}

struct ColorSwatchPicker: View {
    let selectedHex: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ProfilePalette.swatches) { swatch in
                let isSelected = swatch.hex.caseInsensitiveCompare(selectedHex) == .orderedSame
                Button {
                    onSelect(swatch.hex)
                } label: {
                    Circle()
                        .fill(Color(hex: swatch.hex))
                        .frame(width: 26, height: 26)
                        .padding(3)
                        .overlay(Circle().strokeBorder(isSelected ? Color(hex: swatch.hex) : .clear, lineWidth: 2))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// A rounded box used for notes and warnings.
struct NoticeBox<Content: View>: View {
    enum Kind { case info, warning }

    var kind: Kind = .info
    @ViewBuilder var content: Content

    var body: some View {
        let tint: Color = kind == .info ? .blue : .orange
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(tint.opacity(0.35)))
    }
}

struct SectionHeading: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title).font(.headline).accessibilityAddTraits(.isHeader)
    }
}
