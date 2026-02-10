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

    @State private var isVisible = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Backdrop más presente para separar el estado de victoria del juego activo.
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.large) {
                ZStack {
                    // Halo animado para dar sensación de celebración sin ser invasivo.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.appActionPrimary.opacity(glowPulse ? 0.35 : 0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(glowPulse ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)

                    Circle()
                        .fill(Color.appSurfaceCard)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.appBorderSubtle, lineWidth: 1)
                        )

                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.appActionPrimary)
                }

                VStack(spacing: AppTheme.Spacing.xSmall) {
                    Text("¡Ganaste!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Excelente lectura del feedback")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }

                VStack(spacing: AppTheme.Spacing.small) {
                    HStack {
                        Text("Secreto")
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text(secret)
                            .fontDesign(.monospaced)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Intentos")
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text("\(attempts)")
                            .fontWeight(.semibold)
                    }
                }
                .padding(AppTheme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                        .fill(Color.appBackgroundSecondary.opacity(0.6))
                )

                Button {
                    onNewGame()
                } label: {
                    Label("Nueva partida", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .modernProminentButton()  // SwiftUI 2025: Liquid Glass button
                .tint(.appActionPrimary)
            }
            .padding(AppTheme.Spacing.large)
            // SwiftUI 2025: Usar Liquid Glass para el card de victoria
            // - Why: da un efecto premium y celebratorio
            // - isInteractive: false (es una card estática, el botón tiene su propio style)
            // - tintColor: appActionPrimary para énfasis en la celebración
            .glassCard(
                material: .ultraThin,
                padding: 0,  // Ya tenemos padding interno en el VStack
                useLiquidGlass: true,
                isInteractive: false,
                tintColor: Color.appActionPrimary.opacity(0.3)
            )
            .padding(.horizontal, AppTheme.Spacing.large)
            .scaleEffect(isVisible ? 1.0 : 0.96)
            .opacity(isVisible ? 1.0 : 0.0)
            // Entrada suave para evitar el efecto "pop" pobre.
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isVisible)
        }
        // Marca la vista como modal para bloquear interacción debajo.
        .accessibilityAddTraits(.isModal)
        .onAppear {
            // Animación de entrada y halo activo para enfatizar la victoria.
            isVisible = true
            glowPulse = true
        }
    }
}

#Preview("VictorySplashView") {
    VictorySplashView(secret: "50317", attempts: 6, onNewGame: {})
}
