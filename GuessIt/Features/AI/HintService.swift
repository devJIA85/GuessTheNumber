//
//  HintService.swift
//  GuessIt
//
//  Created by Claude on 06/02/2026.
//

import Foundation
import FoundationModels
import NaturalLanguage
import OSLog

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
    private let engine = AppleHintEngine()

    /// Timeout máximo para la generación de una pista (en segundos).
    private static let generationTimeoutSeconds: UInt64 = 15

    /// Límite de requests de pistas por sesión para evitar spam a Apple Intelligence.
    private static let maxRequestsPerSession: Int = 20

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
    
    init() {
        builder = HintPromptBuilder()
    }

    func generateHint(input: HintInput) async throws -> HintOutput {
        try Task.checkCancellation()
        guard requestCount < Self.maxRequestsPerSession else {
            lastErrorDescription = "Límite de requests por sesión alcanzado"
            throw HintError.rateLimited
        }
        requestCount += 1

        let currentEngine = engine
        if currentEngine.isAvailable {
            let prompt = builder.makePrompt(input: input)
            do {
                let text = try await withTimeout(seconds: Self.generationTimeoutSeconds) {
                    try await currentEngine.generate(prompt: prompt)
                }.trimmingCharacters(in: .whitespacesAndNewlines)
                try Task.checkCancellation()
                if !text.isEmpty, builder.isOutputSafe(text, digitCount: input.digitCount) {
                    lastEngineUsed = "apple"
                    lastErrorDescription = nil
                    return HintOutput(text: text)
                }
            } catch {
                if error is CancellationError { throw error }
            }
        }

        // Una salida rechazada o un modelo no disponible tampoco deben dejar al jugador sin pista.
        try Task.checkCancellation()
        lastEngineUsed = "fallback"
        lastErrorDescription = nil
        return HintOutput(text: String(localized: FallbackHintEngine.strategy(for: input.attempts).message))
    }

    static func responseMatchesLanguage(_ fields: [String], locale: Locale) -> Bool {
        guard let language = locale.language.languageCode?.identifier, !fields.isEmpty else {
            return false
        }
        // Evaluamos cada campo por separado para detectar una pista que mezcla idiomas.
        return fields.allSatisfy { NLLanguageRecognizer.dominantLanguage(for: $0)?.rawValue == language }
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
/// - Solo disponible si SystemLanguageModel.default.isAvailable && SystemLanguageModel.default.supportsLocale() == true.
/// - Si el dispositivo no soporta Apple Intelligence, este engine NO se usa.
///
/// # WWDC25: Guided Generation
/// - En iOS 26+ usa `@Generable` (HintResponse) para obtener output estructurado.
/// - El modelo genera campos tipados en vez de texto libre, eliminando la necesidad
///   de parsing manual y reduciendo el riesgo de que el modelo "escape" del formato.
/// - En iOS <26 mantiene la generación de texto plano como fallback.
///
/// # Por qué no cachear session
/// - LanguageModelSession es stateless para single-turn prompts.
/// - Crear session por cada hint es limpio y no tiene overhead significativo.
private struct AppleHintEngine: HintEngine {

    /// Logger para preservar el error original de FoundationModels antes de mapearlo
    /// a `HintError.generationFailed` (el enum tipado no lleva el error subyacente).
    private static let logger = Logger(subsystem: "com.antolini.GuessIt", category: "Hints")

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable && SystemLanguageModel.default.supportsLocale()
    }

    func generate(prompt: String) async throws -> String {
        try Task.checkCancellation()

        // Guided Generation para output estructurado.
        return try await generateStructured(prompt: prompt)
    }

    /// Genera pista con Guided Generation (iOS 26+).
    ///
    /// # WWDC25: @Generable + @Guide
    /// - `session.respond(to:generating:)` produce un `HintResponse` tipado.
    /// - El framework garantiza que el output cumple la estructura definida.
    /// - Las propiedades se generan en orden: diagnóstico → sugerencia → razón,
    ///   lo que permite al modelo construir coherencia entre campos.
    /// - Los `@Guide` descriptions actúan como instrucciones de safety adicionales
    ///   integradas en el schema (ej: "No revelar dígitos concretos").
    @available(iOS 26.0, *)
    private func generateStructured(prompt: String) async throws -> String {
        let locale = Locale.current
        let language = Locale(identifier: "en").localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        let session = LanguageModelSession {
            "Write every field in \(language)."
        }

        let hint: HintResponse
        do {
            hint = try await session.respond(
                to: prompt,
                generating: HintResponse.self
            ).content
        } catch {
            if error is CancellationError { throw error }
            // Preservamos el error real de FoundationModels en el log antes de mapearlo
            // al error tipado (que no lo transporta), para no perder la causa raíz.
            Self.logger.error("FoundationModels generation failed: \(error.localizedDescription, privacy: .public)")
            throw HintError.generationFailed
        }

        try Task.checkCancellation()
        guard HintService.responseMatchesLanguage(
            [hint.diagnostico, hint.proximoIntento, hint.porQue],
            locale: locale
        ) else {
            throw HintError.unsafeOutput
        }

        return [
            String(localized: "Diagnosis: \(hint.diagnostico)"),
            String(localized: "Next guess: \(hint.proximoIntento)"),
            String(localized: "Why: \(hint.porQue)"),
        ].joined(separator: "\n")
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
enum FallbackHintEngine {
    enum Strategy: Equatable {
        case firstGuess, repeated, noneMatch, misplaced, exact

        var message: LocalizedStringResource {
            switch self {
            case .firstGuess: "hint.fallback.first_guess"
            case .repeated: "hint.fallback.repeated"
            case .noneMatch: "hint.fallback.none_match"
            case .misplaced: "hint.fallback.misplaced"
            case .exact: "hint.fallback.exact"
            }
        }
    }

    static func strategy(for attempts: [HintAttempt]) -> Strategy {
        // Los intentos llegan de más reciente a más antiguo. Sólo usamos el feedback visible.
        guard let latest = attempts.first else { return .firstGuess }
        if latest.isRepeated { return .repeated }
        if latest.good + latest.fair == 0 { return .noneMatch }
        if latest.fair > 0 { return .misplaced }
        return .exact
    }
}

// MARK: - Timeout Utility

/// Ejecuta una operación async con timeout.
///
/// Si la operación no completa en el tiempo indicado, cancela la task hija
/// y lanza `HintError.timedOut`.
private func withTimeout<T: Sendable>(
    seconds: UInt64,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw HintError.timedOut
        }

        // El primero que termine gana; cancelamos el otro.
        guard let result = try await group.next() else {
            throw HintError.timedOut
        }
        group.cancelAll()
        return result
    }
}
