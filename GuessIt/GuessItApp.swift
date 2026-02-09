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
    /// Nota: `ModelContainer` no es `Sendable`, por eso lo creamos una sola vez y lo inyectamos en SwiftUI.
    private let modelContainer: ModelContainer

    // MARK: - Composition Root

    /// Environment de alto nivel (actores y dependencias).
    /// `@State` asegura que SwiftUI preserve la instancia a través de recomposiciones.
    @State private var appEnvironment: AppEnvironment

    // MARK: - Init

    init() {
        let container = ModelContainerFactory.make(isInMemory: false)
        self.modelContainer = container
        _appEnvironment = State(initialValue: AppEnvironment(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            GameView()
                // Inyectamos el environment propio de la app.
                .environment(\.appEnvironment, appEnvironment)
        }
        // Inyectamos el contenedor SwiftData a toda la jerarquía.
        .modelContainer(modelContainer)
    }
}

// MARK: - AppEnvironment in SwiftUI Environment

/// Key para exponer `AppEnvironment` en `EnvironmentValues`.
///
/// - Why: permite acceso en cualquier vista sin pasar dependencias por init.
///
/// # Por qué no necesita @MainActor
/// - AppEnvironment ahora es Sendable (no @MainActor), puede construirse en cualquier contexto.
/// - El defaultValue se construye sin aislamiento específico.
private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = {
        // Precondición: este default solo debería usarse en casos extremos.
        // En runtime y previews siempre lo inyectamos explícitamente desde `GuessItApp`.
        let container = ModelContainerFactory.make(isInMemory: true)
        return AppEnvironment(modelContainer: container)
    }()
}

extension EnvironmentValues {
    /// Acceso tipado al `AppEnvironment`.
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// MARK: - Previews

#Preview("Root - InMemory SwiftData") {
    // Previews: usamos in-memory para no ensuciar la base local.
    let container = ModelContainerFactory.make(isInMemory: true)
    let env = AppEnvironment(modelContainer: container)

    return GameView()
        .environment(\.appEnvironment, env)
        .modelContainer(container)
}
