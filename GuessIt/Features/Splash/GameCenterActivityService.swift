//
//  GameCenterActivityService.swift
//  GuessIt
//
//  Created by Claude on 15/02/2026.
//

import Foundation
import GameKit
import Observation
import OSLog

/// Servicio que gestiona las actividades de juego (GKGameActivity) para Apple Games.
///
/// # Responsabilidades
/// - Iniciar y finalizar actividades de juego para aparecer en "Continue Playing".
/// - Reportar estado de juego para "Friends Activity Feed".
/// - Manejar deep links cuando el usuario toca "Continue" en Apple Games.
///
/// # iOS 26+
/// - Las actividades son críticas para máxima visibilidad en Apple Games app.
/// - Sin actividades, el juego no aparece en "Continue Playing" ni en "Home".
///
/// # Arquitectura
/// - `@MainActor` porque GameKit requiere main thread para Activities.
/// - `@Observable` para que SwiftUI observe el estado de actividad.
/// - Implementa `GKLocalPlayerListener` para recibir deep links.
///
/// # Fallo graceful
/// - Si Game Center no está disponible, falla silenciosamente.
@MainActor
@Observable
final class GameCenterActivityService: NSObject, Sendable {
    
    // MARK: - Logging
    
    private static let logger = Logger(subsystem: "com.antolini.GuessIt", category: "GameCenterActivity")
    
    // MARK: - Observable State
    
    /// Actividad actual (nil si no hay ninguna activa).
    private(set) var currentActivity: GKGameActivity?
    
    /// Indica si el servicio está activo y puede crear actividades.
    private(set) var isActive: Bool = false
    
    // MARK: - Activity Identifiers
    
    /// Identificadores de actividades disponibles.
    /// - Note: Deben coincidir con los definidos en App Store Connect o .gkbundle
    enum ActivityType: String {
        case mainGame = "com.antolini.GuessIt.activity.main_game"
        case dailyChallenge = "com.antolini.GuessIt.activity.daily_challenge"
        
        var identifier: String { rawValue }
    }
    
    // MARK: - Init
    
    nonisolated override init() {
        super.init()
    }
    
    // MARK: - Lifecycle
    
    /// Activa el servicio y registra el listener.
    ///
    /// # Cuándo llamar
    /// - Después de que el usuario se autentique en Game Center.
    /// - Desde `GameCenterService.authenticate()` en el handler de éxito.
    func activate() {
        guard !isActive else { return }
        
        // Registrar como listener para recibir eventos de actividades
        GKLocalPlayer.local.register(self)
        isActive = true
        
        Self.logger.info("Activity service activated and registered as listener")
    }
    
    /// Desactiva el servicio y limpia recursos.
    ///
    /// # Cuándo llamar
    /// - Cuando el usuario se desautentica de Game Center.
    /// - Al cerrar la app (opcional, iOS lo maneja automáticamente).
    func deactivate() {
        guard isActive else { return }
        
        // Finalizar actividad actual si existe
        if currentActivity != nil {
            endActivity()
        }
        
        // Desregistrar listener
        GKLocalPlayer.local.unregisterListener(self)
        isActive = false
        
        Self.logger.info("Activity service deactivated")
    }
    
    // MARK: - Activity Management
    
    /// Inicia una actividad de juego.
    ///
    /// # Por qué importante
    /// - Hace que el juego aparezca en "Continue Playing" en Apple Games.
    /// - Permite que amigos vean "Juan está jugando GuessIt" en su feed.
    ///
    /// # Deep Link
    /// - El `identifier` se usa para restaurar el estado cuando el usuario
    ///   toca "Continue" en Apple Games.
    ///
    /// - Parameter type: Tipo de actividad a iniciar.
    func startActivity(type: ActivityType) {
        guard isActive else {
            Self.logger.debug("Skip start activity (service not active)")
            return
        }
        
        // Finalizar actividad anterior si existe
        if currentActivity != nil {
            Self.logger.debug("Ending previous activity before starting new one")
            endActivity()
        }
        
        // TODO: La API de GKGameActivity cambió en iOS 26
        // Ahora requiere GKGameActivityDefinition en lugar de identifier
        // Necesita configuración en App Store Connect o .gkbundle
        Self.logger.warning("GKGameActivity API not fully implemented yet - requires GKGameActivityDefinition from App Store Connect")
        
        /* API correcta de iOS 26 (requiere setup en App Store Connect):
        Task {
            do {
                let definitions = try await GKGameActivityDefinition.all
                guard let definition = definitions.first(where: { $0.identifier == type.identifier }) else {
                    Self.logger.error("Activity definition not found: \(type.identifier)")
                    return
                }
                
                let activity = GKGameActivity(definition: definition)
                activity.start()
                self.currentActivity = activity
                Self.logger.info("Activity started: \(type.identifier)")
            } catch {
                Self.logger.error("Failed to start activity: \(error.localizedDescription)")
            }
        }
        */
    }
    
    /// Finaliza la actividad actual.
    ///
    /// # Nota iOS 26
    /// - La API cambió: `end()` ya no acepta outcome ni completion handler
    /// - El outcome se infiere del estado de la actividad
    func endActivity() {
        guard let activity = currentActivity else {
            Self.logger.debug("No activity to end")
            return
        }
        
        // API de iOS 26: end() ya no toma parámetros
        activity.end()
        Self.logger.info("Activity ended")
        self.currentActivity = nil
    }
    
    /// Actualiza los metadatos de la actividad actual sin finalizarla.
    ///
    /// # Uso
    /// - Actualizar progreso (ej: "Nivel 3/5", "5 intentos restantes").
    /// - Cambiar el contexto sin crear una nueva actividad.
    ///
    /// # Nota
    /// - En iOS 26, esto actualiza el texto visible en el feed de amigos.
    ///
    /// - Parameter metadata: Diccionario con metadatos clave-valor.
    func updateActivityMetadata(_ metadata: [String: Any]) {
        guard currentActivity != nil else {
            Self.logger.debug("No activity to update")
            return
        }
        
        // En iOS 26, puedes actualizar metadatos dinámicamente
        // Por ahora solo logueamos (API futura de Apple)
        Self.logger.debug("Would update activity metadata: \(metadata)")
    }
}

// MARK: - GKLocalPlayerListener

extension GameCenterActivityService: GKLocalPlayerListener {
    
    /// Invocado cuando el usuario toca "Continue Playing" en Apple Games.
    ///
    /// # Responsabilidad
    /// - Restaurar el estado del juego basado en `activity.identifier`.
    /// - Navegar a la pantalla correcta.
    ///
    /// # Deep Link Flow
    /// 1. Usuario toca "Continue" en Apple Games.
    /// 2. iOS lanza la app con el `GKGameActivity` correspondiente.
    /// 3. Este método se invoca con la actividad.
    /// 4. Navegamos al estado correcto del juego.
    nonisolated func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity) async -> Bool {
        await MainActor.run {
            Self.logger.info("Deep link: player wants to play activity \(activity.identifier)")
            
            // La API de iOS 26 cambió: ya no hay propiedad 'handled'
            // El return Bool indica si manejamos la actividad
            
            // Determinar tipo de actividad y actuar
            if activity.identifier == ActivityType.mainGame.identifier {
                Self.logger.info("Resuming main game session")
                // La navegación se maneja automáticamente porque GameView
                // es la root view. No necesitamos navegar explícitamente.
                return true
            } else if activity.identifier == ActivityType.dailyChallenge.identifier {
                Self.logger.info("Resuming daily challenge")
                // TODO: Navegar a DailyChallengeView cuando se implemente navegación profunda
                return true
            } else {
                Self.logger.warning("Unknown activity identifier: \(activity.identifier)")
                return false
            }
        }
    }
}
