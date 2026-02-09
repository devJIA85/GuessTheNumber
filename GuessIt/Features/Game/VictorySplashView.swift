import SwiftUI
import Observation

@Observable
final class VictorySplashState {
    var isPresented: Bool = false
    var didFireHaptic: Bool = false

    // Marca la splash como visible.
    // Por qué: centraliza el estado y evita duplicar lógica en la vista.
    func present() {
        isPresented = true
    }

    // Oculta la splash cuando la partida cambia o el usuario inicia otra.
    func dismiss() {
        isPresented = false
    }

    // Evita repetir el haptic varias veces para la misma victoria.
    func markHapticFired() {
        didFireHaptic = true
    }

    // Resetea el haptic al salir del estado WON.
    func resetHaptic() {
        didFireHaptic = false
    }
}

struct VictorySplashView: View {
    let secret: String
    let attempts: Int
    let onNewGame: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.medium) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.appActionPrimary)

                Text("¡Ganaste!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appTextPrimary)

                VStack(spacing: AppTheme.Spacing.xSmall) {
                    HStack {
                        Text("Secreto:")
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text(secret)
                            .fontDesign(.monospaced)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Intentos:")
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text("\(attempts)")
                            .fontWeight(.semibold)
                    }
                }

                Button {
                    onNewGame()
                } label: {
                    Label("Nueva partida", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appActionPrimary)
            }
            .padding(AppTheme.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.appSurfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .strokeBorder(Color.appBorderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.large)
        }
        // Marca la vista como modal para bloquear interacción debajo.
        .accessibilityAddTraits(.isModal)
    }
}

#Preview("VictorySplashView") {
    VictorySplashView(secret: "50317", attempts: 6, onNewGame: {})
}
