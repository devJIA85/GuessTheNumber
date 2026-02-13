//
//  ModelContainerFactory.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation
import OSLog
import SwiftData

/// Factoría centralizada para construir el `ModelContainer`.
///
/// # Por qué existe
/// - DRY: un único lugar para la configuración del esquema y del store.
/// - Previews/Tests: permite crear contenedores `inMemory` sin tocar disco.
enum ModelContainerFactory {

    private static let logger = Logger(subsystem: "com.antolini.GuessIt", category: "Storage")

    /// Indica si se realizó una recuperación destructiva al inicio.
    /// La app puede leer este flag para mostrar una alerta al usuario.
    static private(set) var didRecoverFromCorruption = false

    /// Construye un `ModelContainer` listo para usarse.
    /// - Parameter isInMemory: `true` para previews/tests (no escribe en disco), `false` para ejecución real.
    static func make(isInMemory: Bool) -> ModelContainer {
        // Listado final de modelos del juego.
        // Mantener este listado en un solo lugar evita inconsistencias y errores sutiles.
        let schema = Schema([
            Game.self,
            Attempt.self,
            DigitNote.self,
            GameStats.self,
            DailyChallenge.self
        ])

        // `isStoredInMemoryOnly` permite un store efímero (ideal para Previews) o persistente (ejecución real).
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isInMemory)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Si falla la creación del contenedor y no estamos en memoria,
            // intentamos eliminar la base de datos corrupta y crear una nueva
            if !isInMemory {
                logger.error("Error al crear ModelContainer: \(error.localizedDescription, privacy: .public)")
                logger.warning("Eliminando base de datos corrupta para recuperar la app...")

                // Eliminar la base de datos existente
                let storeURL = configuration.url
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))

                didRecoverFromCorruption = true

                // Intentar crear nuevamente
                do {
                    logger.info("Base de datos recreada exitosamente tras recuperación.")
                    return try ModelContainer(for: schema, configurations: [configuration])
                } catch {
                    fatalError("No se pudo crear el ModelContainer después de limpiar: \(error)")
                }
            }

            // En un MVP es preferible fallar rápido antes que ejecutar con persistencia inconsistente.
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }
}
