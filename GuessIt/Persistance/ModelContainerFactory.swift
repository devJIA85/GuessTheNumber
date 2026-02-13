//
//  ModelContainerFactory.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation
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
                print("⚠️ Error al crear ModelContainer: \(error)")
                print("🔄 Intentando recrear la base de datos...")
                
                // Eliminar la base de datos existente
                let storeURL = configuration.url
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
                
                // Intentar crear nuevamente
                do {
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
