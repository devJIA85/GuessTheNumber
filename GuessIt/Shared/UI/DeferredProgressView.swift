//
//  DeferredProgressView.swift
//  GuessIt
//
//  Created by Claude on 06/02/2026.
//

import SwiftUI

/// ProgressView diferido para evitar parpadeos en UIs de carga rápida.
///
/// # Problema que resuelve
/// - Cuando una operación async es rápida (< 300ms), mostrar un spinner inmediato
///   genera un parpadeo visual desagradable.
/// - Este componente espera un delay antes de mostrar el spinner.
/// - Si la operación termina antes del delay, el usuario nunca ve el spinner (UX más fluida).
///
/// # Comportamiento
/// 1. `isActive` pasa a `true` → lanzar Task con delay.
/// 2. Si la Task llega al final del delay y `isActive` sigue en `true` → mostrar ProgressView.
/// 3. Si `isActive` vuelve a `false` antes del delay → cancelar Task y no mostrar nada.
///
/// # Por qué 100% SwiftUI
/// - No usamos UIKit wrappers para mantener compatibilidad cross-platform (iOS, macOS).
/// - SwiftUI Task + @State + onChange es suficiente para este patrón.
///
/// # Uso típico
/// ```swift
/// DeferredProgressView(isActive: isLoading, delay: .milliseconds(300))
/// ```
struct DeferredProgressView: View {
    
    // MARK: - Properties
    
    /// Indica si la operación está activa (esperando o en progreso).
    ///
    /// # Responsabilidad del caller
    /// - El caller debe setear `isActive = true` cuando inicia la operación async.
    /// - El caller debe setear `isActive = false` cuando termina la operación.
    let isActive: Bool
    
    /// Tiempo de delay antes de mostrar el spinner.
    ///
    /// # Valores recomendados
    /// - `.milliseconds(300)`: balance entre evitar parpadeos y no hacer esperar al usuario.
    /// - `.milliseconds(500)`: para operaciones que suelen ser muy rápidas.
    let delay: Duration
    
    // MARK: - UI State
    
    /// Controla si el ProgressView debe ser visible.
    ///
    /// # Por qué @State separado de isActive
    /// - `isActive` refleja el estado externo (operación en progreso).
    /// - `shouldShowSpinner` es estado interno (spinner visible después del delay).
    /// - Esta separación permite el patrón diferido: `isActive` puede cambiar antes de que
    ///   `shouldShowSpinner` se vuelva `true`.
    @State private var shouldShowSpinner = false
    
    /// Task que maneja el delay.
    ///
    /// # Por qué guardamos la Task
    /// - Necesitamos cancelarla si `isActive` vuelve a `false` antes del delay.
    /// - Task.cancel() es cooperativo: la Task debe chequear `Task.isCancelled`.
    @State private var delayTask: Task<Void, Never>?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if shouldShowSpinner {
                ProgressView()
                    .controlSize(.large)
                    .tint(.appActionPrimary)
                    // Transición suave para que el spinner no aparezca bruscamente
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            handleActiveStateChange(newValue)
        }
        .onDisappear {
            // Cancelar task si la vista desaparece mientras esperamos
            delayTask?.cancel()
        }
    }
    
    // MARK: - Helpers
    
    /// Maneja cambios en `isActive`.
    ///
    /// # Flujo
    /// - Si `isActive` pasa a `true`:
    ///   1. Cancelar task anterior (si existe).
    ///   2. Crear nueva Task que espera `delay`.
    ///   3. Si la Task termina y `isActive` sigue `true` → mostrar spinner.
    /// - Si `isActive` pasa a `false`:
    ///   1. Cancelar task (si existe).
    ///   2. Ocultar spinner inmediatamente.
    ///
    /// # Por qué @MainActor
    /// - Este método modifica @State, debe ejecutar en MainActor.
    /// - onChange ya ejecuta en MainActor, pero lo hacemos explícito para claridad.
    @MainActor
    private func handleActiveStateChange(_ isNowActive: Bool) {
        if isNowActive {
            // Cancelar task anterior si existe
            delayTask?.cancel()
            
            // Crear nueva task de delay
            delayTask = Task {
                do {
                    // Esperar el delay
                    try await Task.sleep(for: delay)
                    
                    // Si llegamos aquí y NO fuimos cancelados, mostrar spinner
                    // (solo si isActive sigue siendo true)
                    if isActive {
                        shouldShowSpinner = true
                    }
                } catch {
                    // Task fue cancelada, no hacer nada
                    // (CancellationError es el único error posible de Task.sleep)
                }
            }
        } else {
            // isActive pasó a false: cancelar task y ocultar spinner
            delayTask?.cancel()
            delayTask = nil
            shouldShowSpinner = false
        }
    }
}

// MARK: - Previews

#Preview("DeferredProgressView - Carga rápida (< delay)") {
    struct FastLoadPreview: View {
        @State private var isLoading = false
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Simulación de carga rápida (200ms)")
                    .font(.headline)
                
                DeferredProgressView(isActive: isLoading, delay: .milliseconds(300))
                    .frame(height: 100)
                
                Button("Iniciar carga rápida") {
                    isLoading = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        isLoading = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.appActionPrimary)
                
                Text(isLoading ? "Cargando..." : "Listo")
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding()
        }
    }
    
    return FastLoadPreview()
}

#Preview("DeferredProgressView - Carga lenta (> delay)") {
    struct SlowLoadPreview: View {
        @State private var isLoading = false
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Simulación de carga lenta (2s)")
                    .font(.headline)
                
                DeferredProgressView(isActive: isLoading, delay: .milliseconds(300))
                    .frame(height: 100)
                
                Button("Iniciar carga lenta") {
                    isLoading = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        isLoading = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.appActionPrimary)
                
                Text(isLoading ? "Cargando..." : "Listo")
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding()
        }
    }
    
    return SlowLoadPreview()
}
