import SwiftUI

struct AmneziaIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

enum AmneziaButtonStyle {
    case primary
    case secondary
    case destructive
}

struct AmneziaButton: View {
    enum Size {
        case large, medium, small

        var height: CGFloat {
            switch self {
            case .large: return 48
            case .medium: return 40
            case .small: return 36
            }
        }

        var radius: CGFloat {
            switch self {
            case .large: return 16
            case .medium: return 14
            case .small: return 12
            }
        }
    }

    let title: String
    var size: Size = .large
    var style: AmneziaButtonStyle = .primary
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AmneziaTheme.Font.button)
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .background(background)
                .cornerRadius(size.radius)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch style {
        case .primary: return AmneziaTheme.textSecondary
        case .secondary: return AmneziaTheme.bgSurfaceAlt
        case .destructive: return AmneziaTheme.statusDestructive
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return Color(hex: "09090B")
        case .secondary: return AmneziaTheme.textPrimary
        case .destructive: return AmneziaTheme.textPrimary
        }
    }
}

struct AmneziaListItem: View {
    let title: String
    var subtitle: String? = nil
    var iconName: String? = nil
    var showChevron: Bool = false
    var isDestructive: Bool = false
    var trailing: AnyView? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 12) {
                if let iconName {
                    AmneziaIcon(name: iconName, size: 24)
                        .foregroundColor(isDestructive ? AmneziaTheme.statusDestructive : AmneziaTheme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(isDestructive ? AmneziaTheme.statusDestructive : AmneziaTheme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(AmneziaTheme.Font.small)
                            .foregroundColor(AmneziaTheme.textTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if let trailing {
                    trailing
                } else if showChevron {
                    AmneziaIcon(name: "chevron-right", size: 24)
                        .foregroundColor(AmneziaTheme.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct AmneziaTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    @State private var showText = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure && !showText {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(AmneziaTheme.Font.body)
            .foregroundColor(AmneziaTheme.textPrimary)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            if isSecure {
                Button(action: { showText.toggle() }) {
                    AmneziaIcon(name: showText ? "eye-off" : "eye", size: 24)
                        .foregroundColor(AmneziaTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(AmneziaTheme.bgSurfaceAlt)
        .cornerRadius(16)
    }
}

struct AmneziaSwitch: View {
    @Binding var isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(AmneziaToggleStyle())
            .disabled(!isEnabled)
    }
}

struct AmneziaToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 15)
                .fill(configuration.isOn ? AmneziaTheme.accentLight : AmneziaTheme.bgSheet)
                .frame(width: 50, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(configuration.isOn ? AmneziaTheme.accentDark : Color.clear, lineWidth: 1)
                )
            Circle()
                .fill(configuration.isOn ? AmneziaTheme.textPrimary : AmneziaTheme.textTertiary)
                .frame(width: 20, height: 20)
                .padding(5)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        }
    }
}

struct AmneziaSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: { selection = index }) {
                    Text(options[index])
                        .font(AmneziaTheme.Font.button)
                        .foregroundColor(selection == index ? AmneziaTheme.textPrimary : AmneziaTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selection == index ? AmneziaTheme.bgSheet : Color.clear)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AmneziaTheme.bgSurfaceAlt)
        .cornerRadius(16)
    }
}

struct AmneziaRadioButton: View {
    var isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AmneziaTheme.textTertiary, lineWidth: 2)
                .frame(width: 24, height: 24)
            if isSelected {
                Circle()
                    .fill(AmneziaTheme.accentLight)
                    .frame(width: 12, height: 12)
            }
        }
    }
}

struct AmneziaSnackbar: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AmneziaTheme.Font.small)
            .foregroundColor(AmneziaTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AmneziaTheme.bgSheet)
            .cornerRadius(12)
            .shadow(radius: 8)
    }
}

struct AmneziaNavigationBar: View {
    let title: String
    var onBack: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Text(title)
                .font(AmneziaTheme.Font.h3Semibold)
                .foregroundColor(AmneziaTheme.textPrimary)
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        AmneziaIcon(name: "arrow-left", size: 24)
                            .foregroundColor(AmneziaTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        AmneziaIcon(name: "close", size: 24)
                            .foregroundColor(AmneziaTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
    }
}

struct AmneziaConnectButton: View {
    let state: ConnectionState
    let action: () -> Void
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(state.isConnected ? AmneziaTheme.accentLight : AmneziaTheme.borderEmphasis, lineWidth: 2)
                    .frame(width: 190, height: 190)
                if state.isInProgress {
                    Circle()
                        .trim(from: 0, to: 160.0 / 360.0)
                        .stroke(AmneziaTheme.accentLight, lineWidth: 2)
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
                Circle()
                    .fill(AmneziaTheme.bgSurface)
                    .frame(width: 182, height: 182)
                Text(state.text)
                    .font(AmneziaTheme.Font.connectButton)
                    .foregroundColor(AmneziaTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: state.isConnected ? AmneziaTheme.accentLight.opacity(0.35) : Color.clear, radius: 24)
    }
}
