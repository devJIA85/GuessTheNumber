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
    /// 
    /// OPTIMIZACIÓN: Lazy loading para mejorar tiempo de lanzamiento.
    /// - Why: diferir la creación hasta que body se evalúa reduce el tiempo de init()
    private var modelContainer: ModelContainer = {
        ModelContainerFactory.make(isInMemory: false)
    }()

    // MARK: - Composition Root

    /// Environment de alto nivel (actores y dependencias).
    /// `@State` asegura que SwiftUI preserve la instancia a través de recomposiciones.
    /// 
    /// OPTIMIZACIÓN: Lazy loading via wrappedValue.
    /// - Why: diferir la creación de actores hasta que body se evalúa
    @State private var appEnvironment: AppEnvironment?

    // MARK: - Init

    init() {
        // OPTIMIZACIÓN: Init vacío para lanzamiento ultra-rápido
        // - ModelContainer se crea lazy la primera vez que se accede
        // - AppEnvironment se crea en body cuando es necesario
    }

    var body: some Scene {
        WindowGroup {
            // OPTIMIZACIÓN: Crear AppEnvironment lazy la primera vez que body se evalúa
            // - Why: evita crear actores en init(), mejorando tiempo de lanzamiento
            let environment = appEnvironment ?? {
                let env = AppEnvironment(modelContainer: modelContainer)
                appEnvironment = env
                return env
            }()
            
            RootView()
                // Inyectamos el environment propio de la app.
                .environment(\.appEnvironment, environment)
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

    RootView()
        .environment(\.appEnvironment, env)
        .modelContainer(container)
}
