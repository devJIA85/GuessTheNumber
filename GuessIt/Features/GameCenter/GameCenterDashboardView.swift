//
//  GameCenterDashboardView.swift
//  GuessIt
//
//  Created by Claude on 13/02/2026.
//

import SwiftUI
import GameKit

/// Wrapper de SwiftUI sobre el dashboard de Game Center.
///
/// # iOS 26+
/// - Usa la nueva app nativa **Apple Games** a través del sistema operativo.
/// - La presentación es manejada por el sistema, no por `UIViewControllerRepresentable`.
/// - El `GKAccessPoint` es el punto de entrada recomendado por Apple.
///
/// # iOS 13-25 (Fallback)
/// - Usa `GKGameCenterViewController` (deprecado en iOS 26).
/// - Este wrapper permite usarlo con `.fullScreenCover(isPresented:)`.
///
/// # Uso
/// ```swift
/// .fullScreenCover(isPresented: $isShowingGameCenter) {
///     GameCenterDashboardView(state: .dashboard)
/// }
/// ```
struct GameCenterDashboardView: UIViewControllerRepresentable {

    /// Estado inicial del dashboard (`.dashboard`, `.achievements`, `.leaderboards`, etc.).
    let state: GKGameCenterViewControllerState

    func makeUIViewController(context: Context) -> UIViewController {
        // iOS 26+: Apple Games maneja la presentación vía el sistema operativo.
        // Este view controller es un placeholder que se dismissea inmediatamente.
        if #available(iOS 26.0, *) {
            // El dismiss se maneja en showDashboard() del GameCenterService
            // usando GKAccessPoint.showDashboard() o las nuevas APIs de Apple Games.
            let placeholderVC = UIViewController()
            placeholderVC.view.backgroundColor = .clear
            
            // Mostrar el dashboard del sistema automáticamente al presentar
            DispatchQueue.main.async {
                if UIApplication.shared.connectedScenes.first is UIWindowScene {
                    // Presentar el dashboard nativo de Apple Games
                    GKAccessPoint.shared.trigger(state: .dashboard) {
                        // Handler llamado cuando el dashboard se cierra
                    }
                }
            }
            
            return placeholderVC
        } else {
            // iOS 13-25: Usar el ViewController deprecado
            let vc = GKGameCenterViewController(state: state)
            vc.gameCenterDelegate = context.coordinator
            return vc
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Coordinator que implementa `GKGameCenterControllerDelegate` para manejar el dismiss (solo iOS <26).
    final class Coordinator: NSObject {
        @available(iOS, deprecated: 26.0)
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}

// MARK: - Legacy Protocol Conformance (iOS < 26)
@available(iOS, deprecated: 26.0)
extension GameCenterDashboardView.Coordinator: GKGameCenterControllerDelegate {}

