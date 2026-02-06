//
//  GameIdentifier.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftData

/// Tipo alias que encapsula el identificador persistente de SwiftData.
///
/// # Por qué existe este archivo
/// - Evita que la capa de UI tenga imports directos de SwiftData.
/// - Centraliza el tipo de identificador para facilitar cambios futuros.
/// - Mantiene la UI desacoplada de detalles de persistencia.
///
/// # Uso
/// ```swift
/// // En vez de:
/// import SwiftData
/// let id: PersistentIdentifier = game.persistentModelID
///
/// // Usar:
/// let id: GameIdentifier = game.persistentID
/// ```
typealias GameIdentifier = PersistentIdentifier

/// Extension para facilitar acceso al identificador desde la UI.
extension Game {
    /// Identificador persistente de la partida para SwiftData.
    /// - Note: Abstracción sobre `persistentModelID` de SwiftData.
    /// - Why: Evita que la UI dependa directamente de SwiftData.
    var persistentID: GameIdentifier {
        persistentModelID
    }
}
