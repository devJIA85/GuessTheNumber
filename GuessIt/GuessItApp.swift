//
//  GuessItApp.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import SwiftUI
import SwiftData

@main
struct GuessItApp: App {
    // MARK: - SwiftData
    /// Instancia única del contenedor para toda la vida de la app.
    /// Nota: `ModelContainer` no es `Sendable`, por eso lo mantenemos aislado al `MainActor`.
    @MainActor
    private let modelContainer: ModelContainer = ModelContainerFactory.make(isInMemory: false)

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Inyectamos el contenedor en el Environment de SwiftUI.
        .modelContainer(modelContainer)
    }
}

// MARK: - ModelContainerFactory
/// Factoría centralizada para construir el `ModelContainer`.
/// - Por qué: DRY (una única configuración), facilita previews/tests con in-memory y evita configurar SwiftData en varias vistas.
enum ModelContainerFactory {
    /// Construye un `ModelContainer` listo para usarse.
    /// - Parameter isInMemory: `true` para previews/tests (no escribe en disco), `false` para ejecución real.
    @MainActor
    static func make(isInMemory: Bool) -> ModelContainer {
        // TODO: Reemplazar `Item.self` por el listado final de modelos del juego (Game, Attempt, DigitNote, etc.).
        let schema = Schema([
            Item.self
        ])

        // `isStoredInMemoryOnly` permite un store efímero (ideal para Previews).
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isInMemory)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // En un MVP es preferible fallar rápido antes que ejecutar con persistencia inconsistente.
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }
}

// MARK: - Previews
#Preview("Root - InMemory SwiftData") {
    // Previews: usamos in-memory para no ensuciar la base local.
    ContentView()
        .modelContainer(ModelContainerFactory.make(isInMemory: true))
}
