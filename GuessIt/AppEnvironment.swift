//
//  AppEnvironment.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import Foundation
import SwiftData

/// Contenedor de dependencias de alto nivel de la app.
///
/// # Rol
/// - Centraliza la construcción de actores y servicios.
/// - Vive en la capa `App` (composition root).
/// - Se crea desde el `ModelContainer` provisto por SwiftUI.
///
/// # Concurrencia
/// - NO es @MainActor porque contiene actores que manejan su propio aislamiento.
/// - Es Sendable porque todas sus propiedades son Sendable (actores).
/// - Puede ser construido desde MainActor (en GuessItApp) sin problemas.
///
/// # Por qué Sendable
/// - GuessItModelActor: es actor (Sendable por definición).
/// - GameActor: es actor (Sendable por definición).
/// - HintService: es actor (Sendable por definición).
/// - GameCenterService: @MainActor @Observable, Sendable por anotación.
/// - ModelContainer: no es Sendable, pero solo se usa en init y se delega al ModelActor.
final class AppEnvironment: Sendable {

    // MARK: - Dependencias públicas

    /// Actor de persistencia (único punto de acceso a SwiftData).
    let modelActor: GuessItModelActor

    /// Actor de dominio (orquesta validación/evaluación y delega persistencia).
    let gameActor: GameActor

    /// Servicio de pistas AI (opt-in, no afecta reglas del juego).
    let hintService: HintService

    /// Servicio de Game Center (autenticación, logros, GKAccessPoint).
    let gameCenterService: GameCenterService

    // MARK: - Init

    /// Construye el environment a partir del `ModelContainer` inyectado por SwiftUI.
    ///
    /// # Por qué nonisolated
    /// - ModelContainer puede ser construido en MainActor, pero este init no necesita aislamiento.
    /// - Los actores se construyen de forma segura sin requerir MainActor.
    ///
    /// - Parameter modelContainer: contenedor SwiftData de la app.
    nonisolated init(modelContainer: ModelContainer) {
        // Importante: el `@ModelActor` sintetiza un init que acepta `ModelContainer`.
        self.modelActor = GuessItModelActor(modelContainer: modelContainer)
        self.gameActor = GameActor(modelActor: modelActor)

        // Servicio de pistas: verifica disponibilidad de Apple Intelligence en init.
        self.hintService = HintService()

        // Game Center: init nonisolated, autenticación se dispara en RootView.onAppear.
        self.gameCenterService = GameCenterService()

        // Configurar callback para reportar achievements desde el ModelActor.
        // El callback hace el puente entre el actor aislado y @MainActor.
        let gcService = self.gameCenterService
        let reporter: @Sendable ([GameCenterAchievements.AchievementProgress]) -> Void = { achievements in
            Task { @MainActor in
                await gcService.reportAchievements(achievements)
            }
        }

        // Configurar el reporter en el ModelActor (async, no bloquea init).
        let actor = self.modelActor
        Task {
            await actor.setAchievementReporter(reporter)
        }
    }
}
