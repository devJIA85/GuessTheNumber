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
/// - Se marca `@MainActor` porque su creación ocurre desde la UI y porque
///   contiene referencias a infraestructura (SwiftData) que se suele inicializar en el main thread.
@MainActor
final class AppEnvironment {

    // MARK: - Dependencias públicas

    /// Actor de persistencia (único punto de acceso a SwiftData).
    let modelActor: GuessItModelActor

    /// Actor de dominio (orquesta validación/evaluación y delega persistencia).
    let gameActor: GameActor

    // MARK: - Init

    /// Construye el environment a partir del `ModelContainer` inyectado por SwiftUI.
    /// - Parameter modelContainer: contenedor SwiftData de la app.
    init(modelContainer: ModelContainer) {
        // Importante: el `@ModelActor` sintetiza un init que acepta `ModelContainer`.
        self.modelActor = GuessItModelActor(modelContainer: modelContainer)
        self.gameActor = GameActor(modelActor: modelActor)
    }
}
