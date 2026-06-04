import SwiftUI

// MARK: - Buttons

struct MondrianButtonStyle: ButtonStyle {
    var backgroundColor: Color = AppTheme.paper
    
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        // Determine effective background color so we know if we need a border
        let effectiveBackground = isPressed ? AppTheme.ink : backgroundColor
        // Colored backgrounds (Red, Blue, Ochre, Ink) should NOT have a border
        // Only Paper (White) backgrounds get a border
        let hasBorder = effectiveBackground == AppTheme.paper
        
        // Determine text color based on background
        // Rule: Red/Blue = White Text. Yellow/White = Black Text. Ink = White Text.
        let textColor: Color
        if isPressed {
            textColor = AppTheme.paper // Pressed is always Ink background -> White text
        } else {
            switch backgroundColor {
            case AppTheme.accentRed, AppTheme.accentBlue:
                textColor = AppTheme.paper
            case AppTheme.accentOchre, AppTheme.paper:
                textColor = AppTheme.ink
            default:
                textColor = AppTheme.ink
            }
        }

        return configuration.label
            .font(.system(.subheadline, design: .monospaced))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(effectiveBackground)
            .foregroundStyle(textColor)
            .overlay(
                // Only stroke if it's a "paper" style button
                hasBorder ? Rectangle().stroke(AppTheme.ink, lineWidth: 1) : nil
            )
            .offset(x: isPressed ? 2 : 0, y: isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Headers

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            Spacer()
        }
    }
}

// MARK: - Inputs

struct MondrianTextField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            
            if axis == .vertical {
                TextEditor(text: $text)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(AppTheme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(AppTheme.paper)
                    .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
            } else {
                TextField("", text: $text)
                    .font(.system(.body, design: .serif))
                    .padding(12)
                    .background(AppTheme.paper)
                    .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
            }
        }
    }
}

// MARK: - Pickers

struct MondrianPicker<T: Hashable & CustomStringConvertible>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            
            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = option
                        }
                    } label: {
                        Text(option.description.uppercased())
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selection == option ? AppTheme.accentOchre : AppTheme.paper)
                            .foregroundStyle(selection == option ? AppTheme.ink : AppTheme.ink.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    // Add border to items (if not selected, or handle border logic for group)
                    // For a seamless look, we can put a border around the whole container 
                    // and dividers between items, or borders on each.
                    // Let's do borders on each for the "block" look.
                    .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                }
            }
        }
    }
}
