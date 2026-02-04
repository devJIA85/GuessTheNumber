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

// MARK: - Previews
#Preview("Root - InMemory SwiftData") {
    // Previews: usamos in-memory para no ensuciar la base local.
    ContentView()
        .modelContainer(ModelContainerFactory.make(isInMemory: true))
}
