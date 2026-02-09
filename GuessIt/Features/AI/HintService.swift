//
//  HintService.swift
//  GuessIt
//
//  Created by Claude on 06/02/2026.
//

import Foundation
import FoundationModels

/// Servicio de generación de pistas usando Apple Intelligence (Foundation Models).
///
/// # Responsabilidades
/// 1. Verificar disponibilidad de Apple Intelligence.
/// 2. Orquestar la generación de pistas (prompt → modelo → validación).
/// 3. Soportar cancelación de Tasks.
/// 4. Proveer fallback determinista si Apple Intelligence no está disponible.
/// 5. Mantener telemetría local en memoria para QA/debug.
///
/// # Concurrencia
/// - Este servicio es un actor para proteger el estado mutable de telemetría.
/// - Todos los métodos son async/throws y respetan Task.isCancelled.
///
/// # Por qué protocolo HintEngine
/// - Permite separar la lógica de disponibilidad del engine específico.
/// - Facilita testing y fallback sin Apple Intelligence.
///
/// # Por qué actor (antes era class Sendable)
/// - Necesitamos mantener estado mutable (telemetría) thread-safe.
/// - Actor garantiza acceso serializado sin necesidad de locks explícitos.
actor HintService {
    
    private let builder: HintPromptBuilder
    private let engine: any HintEngine
    
    // MARK: - Telemetría (solo memoria)
    
    /// Contador de requests de pistas en esta sesión.
    ///
    /// # Por qué en memoria
    /// - Solo útil para QA/debug, no necesita persistir.
    /// - Se resetea con cada launch de la app.
    private var requestCount: Int = 0
    
    /// Descripción del último error (si hubo).
    ///
    /// # Por qué solo el último
    /// - No necesitamos historial completo de errores para debug.
    /// - El último error suele ser suficiente para diagnosticar problemas.
    private var lastErrorDescription: String? = nil
    
    /// Engine usado en el último request ("apple" o "fallback").
    ///
    /// # Por qué útil
    /// - Permite al QA verificar qué engine está activo.
    /// - Útil para diagnosticar problemas de disponibilidad de Apple Intelligence.
    private var lastEngineUsed: String? = nil
    
    // MARK: - Init
    
    /// Inicializa el servicio de pistas.
    ///
    /// # Disponibilidad
    /// - Si Apple Intelligence está disponible → usa AppleHintEngine.
    /// - Si NO está disponible → usa FallbackHintEngine (heurísticas simples).
    ///
    /// # Por qué verificar en init
    /// - La disponibilidad de Apple Intelligence no cambia durante la vida de la app
    ///   (requiere reinicio de la app si el usuario habilita/deshabilita la feature del sistema).
    /// - Verificar una sola vez reduce overhead.
    init() {
        self.builder = HintPromptBuilder()
        
        // Verificar disponibilidad de Apple Intelligence
        if SystemLanguageModel.default.isAvailable {
            self.engine = AppleHintEngine()
        } else {
            self.engine = FallbackHintEngine()
        }
    }
    
    // MARK: - Public API
    
    /// Genera una pista para la partida actual.
    ///
    /// # Flujo
    /// 1. Incrementar requestCount (telemetría).
    /// 2. Verificar disponibilidad del engine.
    /// 3. Construir prompt con HintPromptBuilder.
    /// 4. Generar texto con el engine.
    /// 5. Validar salida con guardrails.
    /// 6. Actualizar telemetría (engine usado, error si hubo).
    /// 7. Retornar HintOutput.
    ///
    /// # Cancelación
    /// - Respeta Task.isCancelled en cada paso.
    /// - Si se cancela, lanza CancellationError.
    ///
    /// # Errores
    /// - `HintError.unavailable`: el engine no está disponible.
    /// - `HintError.generationFailed`: el engine falló al generar.
    /// - `HintError.unsafeOutput`: la salida violó guardrails.
    ///
    /// - Parameter input: contexto del juego (intentos y notas de dígitos).
    /// - Returns: pista generada (1-4 líneas).
    func generateHint(input: HintInput) async throws -> HintOutput {
        // Telemetría: incrementar contador
        requestCount += 1
        
        // Check cancelación temprano
        try Task.checkCancellation()
        
        do {
            // 1. Verificar disponibilidad
            guard engine.isAvailable else {
                let error = HintError.unavailable
                lastErrorDescription = "Engine no disponible"
                throw error
            }
            
            try Task.checkCancellation()
            
            // 2. Construir prompt
            let prompt = builder.makePrompt(input: input)
            
            try Task.checkCancellation()
            
            // 3. Generar texto con engine (con fallback si Apple Intelligence dispara guardrails)
            let usedEngine: any HintEngine
            let rawText: String
            do {
                rawText = try await engine.generate(prompt: prompt)
                usedEngine = engine
            } catch {
                // Si falla Apple Intelligence por guardrails, usamos fallback para no dejar al usuario sin pista.
                if error is CancellationError {
                    throw error
                }
                if engine is AppleHintEngine {
                    let fallbackEngine = FallbackHintEngine()
                    rawText = try await fallbackEngine.generate(prompt: prompt)
                    usedEngine = fallbackEngine
                } else {
                    throw error
                }
            }
            
            try Task.checkCancellation()
            
            // 4. Validar salida (guardrails)
            guard builder.isOutputSafe(rawText) else {
                let error = HintError.unsafeOutput
                lastErrorDescription = "Output violó guardrails"
                throw error
            }
            
            // 5. Telemetría: registrar engine usado y limpiar último error
            lastEngineUsed = engineName(usedEngine)
            lastErrorDescription = nil
            
            // 6. Retornar resultado
            return HintOutput(text: rawText.trimmingCharacters(in: .whitespacesAndNewlines))
            
        } catch let error as HintError {
            // Registrar error específico de hint
            lastErrorDescription = errorDescription(for: error)
            throw error
        } catch {
            // Error genérico (ej: CancellationError)
            if error is CancellationError {
                lastErrorDescription = "Request cancelado"
            } else {
                lastErrorDescription = "Error inesperado: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    // MARK: - Debug API
    
    /// Retorna información de debug/telemetría de la sesión actual.
    ///
    /// # Uso
    /// - Solo visible en DEBUG builds.
    /// - Útil para QA y desarrollo.
    ///
    /// # No persiste
    /// - Esta info se resetea con cada launch de la app.
    /// - No se guarda en SwiftData ni UserDefaults.
    ///
    /// - Returns: snapshot de la telemetría actual.
    func debugInfo() async -> HintDebugInfo {
        HintDebugInfo(
            requestCount: requestCount,
            lastErrorDescription: lastErrorDescription,
            lastEngineUsed: lastEngineUsed
        )
    }
    
    // MARK: - Helpers (telemetría)
    
    /// Retorna el nombre del engine para telemetría.
    ///
    /// # Por qué este helper
    /// - Evita duplicar lógica de detección de tipo en múltiples lugares.
    /// - Centraliza el mapeo engine → string.
    private func engineName(_ engine: any HintEngine) -> String {
        if engine is AppleHintEngine {
            return "apple"
        } else if engine is FallbackHintEngine {
            return "fallback"
        } else {
            return "unknown"
        }
    }
    
    /// Retorna descripción user-friendly de un HintError.
    ///
    /// # Por qué este helper
    /// - Centraliza el mapeo error → descripción.
    /// - Facilita mantener mensajes consistentes.
    private func errorDescription(for error: HintError) -> String {
        switch error {
        case .unavailable:
            return "Engine no disponible"
        case .generationFailed:
            return "Fallo al generar pista"
        case .unsafeOutput:
            return "Output violó guardrails"
        }
    }
}

// MARK: - HintEngine Protocol

/// Protocolo interno para engines de generación de pistas.
///
/// # Por qué protocolo
/// - Permite múltiples implementaciones (Apple IA, fallback, mock para tests).
/// - Mantiene HintService desacoplado del engine concreto.
///
/// # Sendable
/// - Los engines deben ser Sendable porque se usan desde HintService (que no está en MainActor).
private protocol HintEngine: Sendable {
    
    /// Indica si el engine está disponible para generar pistas.
    var isAvailable: Bool { get }
    
    /// Genera una pista a partir de un prompt.
    ///
    /// # Contrato
    /// - Debe retornar un String con la pista generada.
    /// - Debe lanzar HintError.generationFailed si falla.
    /// - Debe respetar Task.isCancelled.
    ///
    /// - Parameter prompt: prompt construido por HintPromptBuilder.
    /// - Returns: texto de la pista (sin validar, HintService valida después).
    func generate(prompt: String) async throws -> String
}

// MARK: - Apple Intelligence Engine

/// Engine que usa Apple Intelligence (Foundation Models) para generar pistas.
///
/// # Disponibilidad
/// - Solo disponible si SystemLanguageModel.default.isAvailable == true.
/// - Si el dispositivo no soporta Apple Intelligence, este engine NO se usa.
///
/// # Por qué no cachear session
/// - LanguageModelSession es stateless para single-turn prompts.
/// - Crear session por cada hint es limpio y no tiene overhead significativo.
private struct AppleHintEngine: HintEngine {
    
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }
    
    func generate(prompt: String) async throws -> String {
        try Task.checkCancellation()
        
        // Crear session para single-turn prompt
        let session = LanguageModelSession()
        
        do {
            // Configurar opciones con temperatura para aumentar variabilidad
            // Por qué temperatura moderada: queremos respuestas variadas pero sin romper guardrails
            // Por qué 0.7: suficiente creatividad sin sacrificar seguridad (rango típico: 0.0-2.0)
            var options = GenerationOptions()
            options.temperature = 0.7
            
            // Generar respuesta (texto plano, sin structured generation)
            let response = try await session.respond(to: prompt, options: options)
            
            try Task.checkCancellation()
            
            return response.content
        } catch {
            // Mapear errores de FoundationModels a HintError
            throw HintError.generationFailed
        }
    }
}

// MARK: - Fallback Engine (heurísticas)

/// Engine de fallback que genera pistas usando heurísticas simples sin IA.
///
/// # Por qué fallback
/// - Permite que la feature funcione en dispositivos sin Apple Intelligence.
/// - Útil para testing sin depender de la disponibilidad del modelo.
///
/// # Limitaciones
/// - Las pistas son genéricas y menos contextuales que las de IA.
/// - Sigue siendo mejor que no tener pistas.
///
/// # Estrategia de heurísticas
/// - Analizar el historial de intentos (good, fair, poor).
/// - Sugerir acciones basadas en patrones simples.
/// - NO revelar el secreto (cumplir guardrails).
private struct FallbackHintEngine: HintEngine {
    
    var isAvailable: Bool {
        // El fallback siempre está disponible
        true
    }
    
    func generate(prompt: String) async throws -> String {
        try Task.checkCancellation()
        
        // Simular latencia (para UX consistente con Apple engine)
        try await Task.sleep(for: .milliseconds(500))
        
        try Task.checkCancellation()
        
        // Generar pista heurística simple
        // Nota: en una implementación real, parsearíamos el prompt para extraer datos,
        // pero para mantener DRY, generamos pistas genéricas estratégicas.
        
        let hints = [
            "Intentá permutar las posiciones de los dígitos que ya tienen feedback FAIR.",
            "Si tenés varios dígitos GOOD, enfocate en completar las posiciones restantes.",
            "Probá introducir dígitos nuevos para explorar el espacio de búsqueda.",
            "Recordá que POOR significa que ningún dígito del intento está en el secreto.",
            "Si un intento tiene muchos FAIR, el secreto tiene esos dígitos en otras posiciones.",
            "Considera verificar dígitos en posiciones con feedback FAIR, ya que podrían estar cerca del secreto.",
            "Analizá los intentos con más GOOD para identificar patrones de posición.",
            "Si algunos dígitos ya están confirmados (GOOD), concentrá tu búsqueda en las posiciones restantes."
        ]
        
        // Seleccionar hint basado en el timestamp actual + contenido del prompt
        // Esto asegura variabilidad entre llamadas consecutivas
        let seed = Int(Date().timeIntervalSince1970 * 1000) + abs(prompt.count)
        let index = seed % hints.count
        return hints[index]
    }
}
