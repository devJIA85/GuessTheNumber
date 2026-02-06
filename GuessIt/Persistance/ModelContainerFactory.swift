//
//  ModelContainerFactory.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import SwiftData

/// Factoría centralizada para construir el `ModelContainer`.
///
/// # Por qué existe
/// - DRY: un único lugar para la configuración del esquema y del store.
/// - Previews/Tests: permite crear contenedores `inMemory` sin tocar disco.
enum ModelContainerFactory {

    /// Construye un `ModelContainer` listo para usarse.
    /// - Parameter isInMemory: `true` para previews/tests (no escribe en disco), `false` para ejecución real.
    static func make(isInMemory: Bool) -> ModelContainer {
        // Listado final de modelos del juego.
        // Mantener este listado en un solo lugar evita inconsistencias y errores sutiles.
        let schema = Schema([
            Game.self,
            Attempt.self,
            DigitNote.self
        ])

        // `isStoredInMemoryOnly` permite un store efímero (ideal para Previews) o persistente (ejecución real).
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isInMemory)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // En un MVP es preferible fallar rápido antes que ejecutar con persistencia inconsistente.
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }
}
