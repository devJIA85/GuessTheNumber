//
//  HintModels.swift
//  GuessIt
//
//  Created by Claude on 06/02/2026.
//

import Foundation
import FoundationModels
import SwiftData

// MARK: - Input

/// Input Sendable para generar una pista.
/// 
/// # Por qué Sendable
/// - Este DTO cruza boundaries de actor (MainActor → HintService → IA engine).
/// - Debe ser construido desde snapshots, nunca desde @Model directamente.
///
/// # Contenido
/// - `gameID`: identificador de la partida (solo para logging/debug, no se usa en prompt).
/// - `attempts`: historial de intentos para que la IA analice el progreso del jugador.
/// - `digitNotes`: marcas de dígitos (unknown/poor/fair/good) para que la IA sepa qué descartó el jugador.
struct HintInput: Sendable {
    let gameID: PersistentIdentifier
    let attempts: [HintAttempt]
    let digitNotes: [HintDigitNote]
}

/// Snapshot Sendable de un intento para construir el contexto de la pista.
///
/// # Por qué estos campos
/// - `guess`: el número intentado (input del jugador).
/// - `good`, `fair`: feedback del intento.
/// - `isPoor`: indica si el intento fue completamente descartado.
/// - `isRepeated`: marca intentos duplicados (útil para que la IA sugiera explorar nuevos números).
struct HintAttempt: Sendable {
    let guess: String
    let good: Int
    let fair: Int
    let isPoor: Bool
    let isRepeated: Bool
}

/// Snapshot Sendable de una nota de dígito para el contexto de la pista.
///
/// # Por qué
/// - La IA necesita saber qué dígitos ya fueron marcados por el jugador
///   para evitar sugerir dígitos descartados y enfocar la estrategia.
struct HintDigitNote: Sendable {
    let digit: Int
    let mark: DigitMark
}

// MARK: - Structured Output (Guided Generation - WWDC25)

/// Respuesta estructurada del modelo de IA para pistas.
///
/// # WWDC25: Guided Generation
/// - Usa `@Generable` para obtener output tipado del modelo on-device.
/// - Reemplaza la generación de texto libre + parsing manual.
/// - El framework garantiza que el output cumple la estructura definida.
/// - Las propiedades se generan en el orden declarado (importante: diagnóstico
///   informa al modelo antes de generar la sugerencia).
///
/// # Por qué @Generable en vez de texto libre
/// - Elimina la fragilidad del parsing de texto con regex.
/// - Reduce falsos positivos en guardrails (el modelo no puede "escapar" del formato).
/// - Mejora la UX: campos separados permiten renderizado diferenciado en la UI.
///
/// # Disponibilidad
/// - Solo disponible en iOS 26+ (requiere FoundationModels con Guided Generation).
/// - El fallback (FallbackHintEngine) sigue generando texto plano.
@available(iOS 26.0, *)
@Generable
struct HintResponse {
    @Guide(description: "Diagnóstico breve del estado actual del juego basado en los intentos. No revelar dígitos concretos ni posiciones.")
    var diagnostico: String

    @Guide(description: "Sugerencia táctica para el próximo intento. No mencionar dígitos concretos, posiciones exactas, ni dar la respuesta.")
    var proximoIntento: String

    @Guide(description: "Razón breve de por qué se sugiere esa estrategia.")
    var porQue: String
}

// MARK: - Output

/// Resultado de generar una pista.
///
/// # Por qué simple
/// - La pista es solo texto (1-4 líneas).
/// - No hay metadata adicional necesaria.
/// - Equatable para permitir comparaciones en tests.
struct HintOutput: Sendable, Equatable {
    let text: String
}

// MARK: - Errores

/// Errores tipados del sistema de pistas.
///
/// # Casos
/// - `unavailable`: el dispositivo/entorno no soporta generación de pistas (sin Apple Intelligence).
/// - `generationFailed`: la IA falló al generar la pista (timeout, red, etc.).
/// - `unsafeOutput`: la salida de la IA violó los guardrails de seguridad (reveló el secreto, etc.).
enum HintError: Error, Sendable {
    case unavailable
    case generationFailed
    case unsafeOutput
}

// MARK: - Debug / Telemetría

/// Información de debug para QA y desarrollo (solo memoria, no persiste).
///
/// # Por qué solo memoria
/// - No queremos persistir pistas ni métricas en SwiftData (complejidad innecesaria).
/// - Esta info solo es útil durante desarrollo y QA.
/// - Se resetea con cada sesión de la app.
///
/// # Contenido
/// - `requestCount`: total de requests de pistas en esta sesión.
/// - `lastErrorDescription`: descripción del último error (si hubo).
/// - `lastEngineUsed`: qué engine se usó en el último request ("apple" o "fallback").
struct HintDebugInfo: Sendable, Equatable {
    var requestCount: Int
    var lastErrorDescription: String?
    var lastEngineUsed: String?
}
