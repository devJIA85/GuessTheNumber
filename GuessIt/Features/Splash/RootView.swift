//
//  RootView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 11/02/2026.
//

import SwiftUI
import SwiftData
import GameKit

// MARK: - RootView (Contenedor raíz con Splash)

/// Vista raíz que orquesta la splash animada sobre el contenido principal.
///
/// # Arquitectura
/// - `GameView` se monta con una pequeña demora (prewarm) antes de que termine la splash.
/// - `SplashView` se superpone como overlay y se auto-remueve al finalizar.
/// - El estado `isSplashActive` vive aquí como fuente de verdad.
///
/// # Por qué prewarm diferido
/// - Cargar `GameView` demasiado temprano puede competir con el render inicial.
/// - Cargarlo demasiado tarde genera un salto visual al cerrar la splash.
/// - Se monta ~0.9s después del arranque para equilibrar suavidad y tiempo de carga.
///
/// # Flujo
/// 1. App inicia → `RootView` se monta.
/// 2. `GameView` comienza a cargar datos en background.
/// 3. `SplashView` cubre todo con la animación (~1.2s).
/// 4. Al terminar, `isSplashActive = false` → splash se remueve.
/// 5. `GameView` ya está listo y visible.
struct RootView: View {

    // MARK: - Dependencies

    /// Acceso al composition root para Game Center.
    @Environment(\.appEnvironment) private var env

    // MARK: - State

    /// Controla la visibilidad de la splash screen.
    /// - Inicia en `true` y se pone en `false` cuando la animación termina.
    @State private var isSplashActive = true

    /// Controla si GameView ya fue cargado.
    /// OPTIMIZACIÓN: Diferir carga de GameView hasta que sea necesario
    /// - Why: evita montar GameView.task {} durante el lanzamiento
    @State private var isGameViewLoaded = false

    /// Controla la visibilidad del tutorial.
    /// OPTIMIZACIÓN: Lazy loading via computed property
    /// - Why: evita acceso a UserDefaults en init
    @State private var isTutorialPresented = false
    @State private var hasCheckedTutorial = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // OPTIMIZACIÓN: Cargar GameView solo cuando la splash está por terminar
            // - Why: evita montar toda la jerarquía de GameView durante el lanzamiento
            // - GameView se carga ~0.3s antes de que la splash termine para precarga
            Group {
                if isGameViewLoaded {
                    GameView()
                        // Accesibilidad: ocultar contenido principal mientras splash está activa.
                        // - Why: evita que VoiceOver lea el juego mientras el usuario ve la splash.
                        .accessibilityHidden(isSplashActive)
                        .transition(.opacity)
                } else {
                    // Mantener el primer slot del ZStack estable para no recrear SplashView.
                    Color.clear.ignoresSafeArea()
                }
            }

            // SPLASH OVERLAY: SIEMPRE visible al inicio, se auto-remueve cuando isActive se pone en false.
            // - Why: debe estar siempre presente al inicio para evitar flashes
            if isSplashActive {
                SplashView(isActive: $isSplashActive)
                    // Transición de salida: .identity porque SplashView maneja su propia
                    // animación de salida (dissolve). No queremos que SwiftUI agregue
                    // una transición por defecto que interfiera.
                    .transition(.identity)
                    // Evitar que taps atraviesen la splash al contenido.
                    // - Why: sin esto, el usuario podría interactuar con GameView
                    //   mientras la splash está visible.
                    .allowsHitTesting(true)
                    // Z-Index alto para asegurar que siempre esté encima
                    .zIndex(100)
            }
        }
        .onAppear {
            // OPTIMIZACIÓN: Cargar GameView justo antes de que la splash termine
            // - Why: la splash comienza a disolverse en ~0.75s y termina en ~1.2s
            // - Cargamos GameView en 0.9s para que esté listo cuando la splash desaparezca
            // - Esto evita que se vea GameView detrás de la splash mientras anima
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                isGameViewLoaded = true
            }

            // OPTIMIZACIÓN: Check del tutorial diferido
            // - Why: no bloquea el lanzamiento inicial
            if !hasCheckedTutorial {
                hasCheckedTutorial = true
                isTutorialPresented = !UserDefaults.standard.bool(forKey: "hasCompletedTutorial")
            }

            // Game Center: autenticación no bloqueante al lanzar la app.
            // - Why: debe ejecutarse lo antes posible para que GKAccessPoint aparezca.
            // - Si el usuario no está logueado, Game Center muestra su overlay nativo.
            // - Si ya está logueado, se activa inmediatamente sin UI visible.
            env.gameCenterService.authenticate()
            
            // iOS 26+: Configurar GKAccessPoint (Liquid Glass badge)
            // - Why: Apple Games requiere este badge visible para máxima visibilidad.
            // - El badge aparece automáticamente cuando el usuario está autenticado.
            // - Se auto-oculta si el usuario no está logueado o tiene restricciones.
            if #available(iOS 26.0, *) {
                configureGameCenterAccessPoint()
            }
        }
        .fullScreenCover(isPresented: $isTutorialPresented) {
            TutorialView(isPresented: $isTutorialPresented)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Configura el GKAccessPoint para iOS 26+ (Liquid Glass badge).
    ///
    /// # Por qué existe
    /// - Apple Games requiere que el badge de Game Center esté visible.
    /// - El badge sirve como punto de entrada para el usuario a la app Apple Games.
    /// - Se auto-oculta si el usuario no está autenticado.
    ///
    /// # Ubicación
    /// - `.topLeading`: esquina superior izquierda (recomendación de Apple).
    /// - No interfiere con otros controles de la app.
    ///
    /// # Highlights
    /// - En iOS 26+, los highlights se gestionan automáticamente por el sistema.
    /// - El badge tiene animación Liquid Glass al tocarlo.
    @available(iOS 26.0, *)
    private func configureGameCenterAccessPoint() {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.isActive = true
    }
}

// MARK: - Preview

#Preview("RootView - Con Splash") {
    let container = ModelContainerFactory.make(isInMemory: true)
    let env = AppEnvironment(modelContainer: container)

    RootView()
        .environment(\.appEnvironment, env)
        .modelContainer(container)
}
