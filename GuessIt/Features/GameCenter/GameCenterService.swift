//
//  GameCenterService.swift
//  GuessIt
//
//  Created by Claude on 13/02/2026.
//

import Foundation
import GameKit
import Observation
import OSLog

/// Servicio centralizado de integración con Game Center.
///
/// # Responsabilidades
/// - Autenticación del jugador local (`GKLocalPlayer`).
/// - Presentación del dashboard de Game Center (logros).
/// - Reporte de achievements a Game Center.
///
/// # Concurrencia
/// - `@MainActor` porque GameKit requiere MainActor para:
///   - `GKLocalPlayer.authenticateHandler` (callbacks en main thread).
///   - Presentación de UI de autenticación.
/// - `@Observable` para que SwiftUI observe `isAuthenticated` reactivamente.
///
/// # Arquitectura
/// - Vive en `AppEnvironment` como dependencia inyectada.
/// - Se autentica en `RootView.onAppear` (no bloqueante).
/// - Los achievements se reportan via callback desde `GuessItModelActor`.
///
/// # Fallo graceful
/// - Si Game Center no está disponible o el usuario no está logueado,
///   todos los métodos fallan silenciosamente (no crashean).
@MainActor
@Observable
final class GameCenterService: Sendable {

    // MARK: - Logging

    private static let logger = Logger(subsystem: "com.antolini.GuessIt", category: "GameCenter")

    // MARK: - Observable State

    /// Indica si el jugador está autenticado en Game Center.
    private(set) var isAuthenticated: Bool = false

    /// Último error de autenticación (para debug/logging).
    private(set) var lastAuthError: String?

    // MARK: - Init

    /// Init vacío. La autenticación se dispara explícitamente con `authenticate()`.
    nonisolated init() {}

    // MARK: - Authentication

    /// Autentica al jugador local en Game Center.
    ///
    /// # Cuándo llamar
    /// - Desde `RootView.onAppear` (una vez por lanzamiento de app).
    ///
    /// # UX
    /// - Si el usuario no está logueado, Game Center presenta su propia UI de login
    ///   (overlay Liquid Glass en iOS 26).
    /// - Si ya está logueado, el handler se ejecuta inmediatamente sin UI visible.
    /// - Si hay restricciones parentales o de red, falla silenciosamente.
    ///
    /// # Re-invocaciones
    /// - iOS 26 puede re-invocar el handler si el usuario cambia de cuenta en Settings.
    /// - El handler maneja este caso actualizando `isAuthenticated`.
    func authenticate() {
        let localPlayer = GKLocalPlayer.local

        localPlayer.authenticateHandler = { [weak self] viewController, error in
            // authenticateHandler se invoca en main thread, pero debemos
            // asegurar el aislamiento de @MainActor explícitamente.
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    Self.logger.error("Auth error: \(error.localizedDescription)")
                    self.isAuthenticated = false
                    self.lastAuthError = error.localizedDescription
                    return
                }

                if let vc = viewController {
                    // Game Center necesita presentar UI de login.
                    self.presentAuthenticationOverlay(vc)
                    return
                }

                if localPlayer.isAuthenticated {
                    Self.logger.info("Authenticated: \(localPlayer.displayName)")
                    self.isAuthenticated = true
                    self.lastAuthError = nil
                } else {
                    self.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Dashboard

    /// Indica si el dashboard de Game Center debe mostrarse.
    ///
    /// # SwiftUI Integration
    /// - Vinculado al modificador `.gameCenter(isPresented:)` en SwiftUI.
    /// - Se setea en `true` cuando el usuario toca el botón de Game Center.
    /// - SwiftUI lo vuelve a `false` automáticamente cuando se cierra el dashboard.
    var isShowingGameCenter: Bool = false

    /// Presenta el dashboard de Game Center (logros, leaderboards).
    ///
    /// # Cuándo llamar
    /// - Desde el botón de Game Center en la toolbar de `GameView`.
    ///
    /// # Implementación (iOS 26+)
    /// - Usa el nuevo API de SwiftUI `.gameCenter(isPresented:)`.
    /// - Simplemente setea `isShowingGameCenter = true`.
    /// - SwiftUI maneja la presentación y el dismiss automáticamente.
    ///
    /// # Fallo graceful
    /// - Si no está autenticado, no hace nada.
    func showDashboard() {
        guard isAuthenticated else { return }
        isShowingGameCenter = true
    }

    // MARK: - Achievement Reporting

    /// Reporta un achievement a Game Center.
    ///
    /// # Idempotencia
    /// - Game Center ignora reports con percent <= al ya reportado.
    /// - Safe llamar múltiples veces con el mismo achievement.
    ///
    /// # Fallo graceful
    /// - Si no está autenticado, no hace nada (no crashea).
    /// - Si el report falla, logea el error pero no lo propaga.
    ///
    /// - Parameters:
    ///   - identifier: ID del achievement (ej: "com.antolini.GuessIt.achievement.first_win").
    ///   - percentComplete: progreso 0.0–100.0 (100.0 = desbloqueado).
    func reportAchievement(identifier: String, percentComplete: Double) async {
        guard isAuthenticated else {
            Self.logger.debug("Skip achievement report (not authenticated): \(identifier)")
            return
        }

        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true

        do {
            try await GKAchievement.report([achievement])
            Self.logger.info("Achievement reported: \(identifier) at \(percentComplete)%")
        } catch {
            Self.logger.error("Achievement report failed for \(identifier): \(error.localizedDescription)")
        }
    }

    /// Reporta múltiples achievements en batch.
    ///
    /// # Por qué batch
    /// - Más eficiente que reportar uno por uno (una sola request a Game Center).
    /// - Garantiza atomicidad (todos se reportan o ninguno).
    ///
    /// - Parameter achievements: lista de achievements con su progreso.
    func reportAchievements(_ achievements: [GameCenterAchievements.AchievementProgress]) async {
        guard isAuthenticated, !achievements.isEmpty else { return }

        let gkAchievements = achievements.map { progress -> GKAchievement in
            let achievement = GKAchievement(identifier: progress.id)
            achievement.percentComplete = progress.percentComplete
            achievement.showsCompletionBanner = true
            return achievement
        }

        do {
            try await GKAchievement.report(gkAchievements)
            Self.logger.info("Batch reported \(achievements.count) achievements")
        } catch {
            Self.logger.error("Batch achievement report failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Presenta el View Controller de autenticación de Game Center.
    ///
    /// # iOS 26
    /// - El VC es un overlay Liquid Glass del sistema.
    /// - Debe presentarse sobre la jerarquía de vistas activa.
    private func presentAuthenticationOverlay(_ viewController: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            Self.logger.error("Cannot present auth overlay: no root VC")
            return
        }

        // Navegar hasta el VC más alto en la jerarquía de presentación
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(viewController, animated: true)
    }
}


