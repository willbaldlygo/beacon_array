import SwiftUI

// MARK: - Buttons

struct MondrianButtonStyle: ButtonStyle {
    var backgroundColor: Color = AppTheme.surfaceContainerLowest
    
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let effectiveBackground = isPressed ? AppTheme.primary : backgroundColor
        
        let textColor: Color
        if isPressed {
            textColor = AppTheme.onPrimary
        } else {
            if backgroundColor == AppTheme.secondary || backgroundColor == AppTheme.error {
                textColor = Color.white
            } else {
                textColor = AppTheme.primary
            }
        }

        return configuration.label
            .font(.system(.subheadline, design: .monospaced))
            .fontWeight(.bold)
            .textCase(.uppercase)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(effectiveBackground)
            .foregroundStyle(textColor)
            .overlay(
                Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border)
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
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.onSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.secondary)
        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
    }
}

// MARK: - Inputs

struct MondrianTextField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.primary.opacity(0.6))
            
            if axis == .vertical {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppTheme.primary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(AppTheme.surfaceContainerLowest)
                    .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
            } else {
                TextField("", text: $text)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(AppTheme.surfaceContainerLowest)
                    .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.primary.opacity(0.6))
            
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
                            .background(selection == option ? AppTheme.tertiaryFixed : AppTheme.surfaceContainerLowest)
                            .foregroundStyle(AppTheme.primary)
                    }
                    .buttonStyle(.plain)
                    .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                }
            }
        }
    }
}

// MARK: - Pill Button Style

struct MondrianPillButtonStyle: ButtonStyle {
    var backgroundColor: Color = AppTheme.surfaceContainerLowest
    var hasOffsetShadow: Bool = true
    var verticalPadding: CGFloat = 16
    var horizontalPadding: CGFloat = 24
    var fixedHeight: CGFloat? = nil
    
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let effectiveBackground = isPressed ? AppTheme.primary : backgroundColor
        
        let textColor: Color
        if isPressed {
            textColor = AppTheme.onPrimary
        } else {
            if backgroundColor == AppTheme.secondary || backgroundColor == AppTheme.error {
                textColor = Color.white
            } else {
                textColor = AppTheme.primary
            }
        }
        
        return configuration.label
            .font(.system(.subheadline, design: .monospaced))
            .fontWeight(.bold)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, horizontalPadding)
            .frame(height: fixedHeight)
            .padding(.vertical, fixedHeight == nil ? verticalPadding : 0)
            .foregroundStyle(textColor)
            .background(
                Capsule()
                    .fill(effectiveBackground)
                    .shadow(color: hasOffsetShadow && !isPressed ? AppTheme.primary : Color.clear, radius: 0, x: hasOffsetShadow && !isPressed ? 4 : 0, y: hasOffsetShadow && !isPressed ? 4 : 0)
            )
            .overlay(
                Capsule().stroke(AppTheme.primary, lineWidth: 2)
            )
            .offset(x: isPressed ? 2 : 0, y: isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Orbital Visualizer

struct MondrianOrbitalSystem: View {
    let isSmall: Bool
    var showVoiceIcon: Bool = false
    
    @State private var slowRotation: Double = 0
    @State private var fastRotation: Double = 0
    @State private var pulseScale: CGFloat = 0.95
    
    var body: some View {
        let containerHeight: CGFloat = isSmall ? 256 : 360
        let innerOrbitSize: CGFloat = isSmall ? 100 : 144
        let outerOrbitSize: CGFloat = isSmall ? 150 : 224
        let innerPlanetSize: CGFloat = isSmall ? 12 : 20
        let outerPlanetSize: CGFloat = isSmall ? 18 : 32
        let centerSize: CGFloat = isSmall ? 36 : 64
        
        ZStack {
            // Background Grid Dot Texture
            GeometryReader { geo in
                Path { path in
                    let dotSpacing: CGFloat = 20
                    let cols = Int(geo.size.width / dotSpacing) + 1
                    let rows = Int(geo.size.height / dotSpacing) + 1
                    for c in 0..<cols {
                        for r in 0..<rows {
                            path.addEllipse(in: CGRect(x: CGFloat(c) * dotSpacing, y: CGFloat(r) * dotSpacing, width: 2, height: 2))
                        }
                    }
                }
                .fill(AppTheme.primary.opacity(0.05))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Orbits Container
            ZStack {
                // Outer Orbit (Ochre Planet)
                Circle()
                    .stroke(AppTheme.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: outerOrbitSize, height: outerOrbitSize)
                    .overlay(alignment: .top) {
                        Circle()
                            .fill(AppTheme.tertiaryFixedDim)
                            .frame(width: outerPlanetSize, height: outerPlanetSize)
                            .overlay(Circle().stroke(AppTheme.primary, lineWidth: 1))
                            .offset(y: -outerPlanetSize / 2)
                    }
                    .rotationEffect(.degrees(fastRotation + 135)) // offset starting angle
                
                // Inner Orbit (Red Planet)
                Circle()
                    .stroke(AppTheme.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: innerOrbitSize, height: innerOrbitSize)
                    .overlay(alignment: .top) {
                        Circle()
                            .fill(AppTheme.error)
                            .frame(width: innerPlanetSize, height: innerPlanetSize)
                            .overlay(Circle().stroke(AppTheme.primary, lineWidth: 1))
                            .offset(y: -innerPlanetSize / 2)
                    }
                    .rotationEffect(.degrees(slowRotation))
                
                // Center Node
                Group {
                    if showVoiceIcon {
                        Circle()
                            .fill(AppTheme.secondary)
                            .frame(width: centerSize, height: centerSize)
                            .overlay(Circle().stroke(AppTheme.primary, lineWidth: 2))
                            .overlay {
                                Image(systemName: "waveform")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                            .shadow(color: AppTheme.primary.opacity(0.2), radius: 8)
                    } else {
                        Circle()
                            .fill(AppTheme.onSecondaryContainer)
                            .frame(width: centerSize, height: centerSize)
                            .overlay(Circle().stroke(AppTheme.primary, lineWidth: 2))
                    }
                }
                .scaleEffect(pulseScale)
            }
            .frame(width: outerOrbitSize, height: outerOrbitSize)
            
            // Sync Label Badge (For Voice screen) - Removed
        }
        .frame(height: containerHeight)
        .frame(maxWidth: .infinity)
        .onAppear {
            // Keep rotation continuous and linear
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                slowRotation = 360
            }
            withAnimation(.linear(duration: isSmall ? 12 : 20).repeatForever(autoreverses: false)) {
                fastRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
}

// MARK: - Acoustic Field Visualizer

struct AcousticFieldVisualizer: View {
    let audioLevel: Float
    
    var body: some View {
        HStack(spacing: 4) {
            bar(baseHeight: 12, maxHeight: 28, color: AppTheme.primary, scaleMultiplier: 1.0)
            bar(baseHeight: 24, maxHeight: 44, color: AppTheme.secondary, scaleMultiplier: 1.2)
            bar(baseHeight: 16, maxHeight: 32, color: AppTheme.primary, scaleMultiplier: 0.8)
            bar(baseHeight: 32, maxHeight: 52, color: AppTheme.error, scaleMultiplier: 1.5)
            bar(baseHeight: 20, maxHeight: 36, color: AppTheme.secondary, scaleMultiplier: 1.1)
        }
        .frame(height: 52)
    }
    
    @ViewBuilder
    private func bar(baseHeight: CGFloat, maxHeight: CGFloat, color: Color, scaleMultiplier: Float) -> some View {
        let level = min(max(audioLevel * scaleMultiplier, 0.0), 1.0)
        let height = baseHeight + (maxHeight - baseHeight) * CGFloat(level)
        
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 4, height: height)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6, blendDuration: 0), value: height)
    }
}
