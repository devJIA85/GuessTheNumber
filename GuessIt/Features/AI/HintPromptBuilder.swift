//
//  HintPromptBuilder.swift
//  GuessIt
//
//  Created by Claude on 06/02/2026.
//

import Foundation

// MARK: - HintPromptBuilder

/// Constructor de prompts para la generación de pistas y validación de salida.
///
/// # Responsabilidades
/// 1. Transformar `HintInput` en un prompt estructurado para el modelo de IA.
/// 2. Aplicar guardrails a la salida del modelo para evitar violaciones de las reglas del juego.
///
/// # Guardrails implementados
/// - NO revelar el secreto (5 dígitos consecutivos).
/// - NO dar respuestas directas tipo "el número es X".
/// - Bloquear frases que violan el espíritu del juego.
///
/// # Por qué Sendable
/// - Este builder será usado desde HintService que puede ejecutar en cualquier contexto de actor.
struct HintPromptBuilder: Sendable {
    
    // MARK: - Prompt Construction
    
    /// Métricas derivadas de intentos para orientar la pista sin resolver el secreto.
    /// - Why: aportan precisión táctica con información agregada y segura.
    private struct DerivedStats {
        let bestHit: Int
        let bestAttemptIndex: Int
        let last3Trend: String
        let repeatedCount: Int
        let poorStreak: Int
        let newDigitsRate: Int
        
        /// Bloque listo para el prompt con métricas resumidas.
        /// - Why: guía al modelo con datos concretos sin mencionar dígitos ni posiciones.
        var asPromptBlock: String {
            """
            Resumen táctico (derivado, sin resolver):
            - Mejor hit (GOOD+FAIR): \(bestHit) (intento \(bestAttemptIndex))
            - Tendencia últimos 3: \(last3Trend)
            - Repetidos: \(repeatedCount)
            - Racha POOR: \(poorStreak)
            - Nuevos en último intento vs anterior: \(newDigitsRate)
            """
        }
    }
    
    /// Construye un prompt estructurado para el modelo de IA.
    ///
    /// # Estrategia del prompt
    /// - Contextualizar el juego (reglas básicas sin revelar el secreto).
    /// - Proveer el historial de intentos con feedback.
    /// - Proveer las marcas de dígitos actuales.
    /// - Instruir al modelo sobre QUÉ puede y NO puede hacer.
    ///
    /// # Por qué incluir reglas explícitas
    /// - Los modelos de lenguaje necesitan instrucciones claras para evitar respuestas prohibidas.
    /// - Un prompt estructurado reduce la probabilidad de salidas inseguras.
    ///
    /// - Parameter input: datos del juego (intentos y notas de dígitos).
    /// - Returns: prompt listo para enviar al modelo.
    func makePrompt(input: HintInput) -> String {
        var sections: [String] = []
        
        // 1. Instrucciones del rol
        sections.append("""
        Eres un asistente de estrategia para un juego tipo Mastermind numérico.
        El jugador debe adivinar un número secreto de 5 dígitos (0-9, sin repetir).
        
        Reglas del feedback:
        - GOOD: dígito correcto en posición correcta.
        - FAIR: dígito correcto en posición incorrecta.
        - POOR: ningún dígito del intento está en el secreto.
        """)
        
        // 2. Historial de intentos
        if input.attempts.isEmpty {
            sections.append("El jugador aún no ha hecho intentos.")
        } else {
            var attemptsText = "Historial de intentos:\n"
            for (index, attempt) in input.attempts.enumerated() {
                let repeated = attempt.isRepeated ? " (REPETIDO)" : ""
                let poor = attempt.isPoor ? " POOR" : ""
                attemptsText += "\(index + 1). \(attempt.guess) → GOOD: \(attempt.good), FAIR: \(attempt.fair)\(poor)\(repeated)\n"
            }
            sections.append(attemptsText)
            
            if let stats = derivedStats(from: input.attempts) {
                // Métricas seguras: resumen táctico sin inferir posiciones ni revelar dígitos concretos.
                sections.append(stats.asPromptBlock)
            }
        }
        
        // 3. Marcas de dígitos
        let markedDigits = input.digitNotes.filter { $0.mark != .unknown }
        if !markedDigits.isEmpty {
            var notesText = "Notas del jugador sobre dígitos:\n"
            for note in markedDigits.sorted(by: { $0.digit < $1.digit }) {
                let markText: String
                switch note.mark {
                case .good:
                    markText = "CONFIRMADO (posición correcta)"
                case .fair:
                    markText = "EN EL SECRETO (posición incorrecta)"
                case .poor:
                    markText = "DESCARTADO"
                case .unknown:
                    continue
                }
                notesText += "Dígito \(note.digit): \(markText)\n"
            }
            sections.append(notesText)
        } else {
            sections.append("El jugador aún no ha marcado ningún dígito.")
        }
        
        // 4. Instrucciones de la pista (QUÉ hacer y QUÉ NO hacer)
        //
        // WWDC25 Safety Best Practice: las instrucciones de safety en mayúsculas
        // mejoran la defensa contra prompt injection (Apple Research).
        // El modelo está entrenado para priorizar instructions sobre prompts.
        //
        // Nota: en iOS 26+ con Guided Generation, el formato es manejado por el schema
        // (@Generable), pero las instrucciones de safety siguen siendo necesarias
        // porque el contenido de cada campo sigue siendo texto libre.
        let timestamp = Date().timeIntervalSince1970
        sections.append("""

        Tu tarea:
        Proporciona UNA pista táctica, breve, textual y no determinista.

        LO QUE PUEDES hacer:
        - Dar instrucciones accionables sin mencionar dígitos concretos ni posiciones.
        - Recomendar experimentos controlados (p. ej., reusar parte del mejor intento y variar pocas piezas).
        - Basarte en el resumen táctico para priorizar el siguiente movimiento.

        LO QUE NO PUEDES HACER (REGLAS DE SEGURIDAD OBLIGATORIAS):
        - NO REVELAR EL SECRETO NI DAR 5 DÍGITOS CONSECUTIVOS.
        - NO DECIR "EL NÚMERO ES..." O "LA RESPUESTA ES...".
        - NO PROPORCIONAR UN ÚNICO INTENTO ESPECÍFICO COMO SOLUCIÓN FINAL.
        - NO USAR LENGUAJE DE SOLVER NI ENUMERAR COMBINACIONES.
        - NO MENCIONAR DÍGITO + POSICIÓN (EJ: "7 EN LA POSICIÓN 3").

        Responde SOLO con la pista, sin preámbulos ni explicaciones adicionales.

        [Request ID: \(Int(timestamp))]
        """)
        
        return sections.joined(separator: "\n\n")
    }
    
    /// Calcula métricas tácticas derivadas de los intentos.
    /// - Why: son señales agregadas que no revelan dígitos ni posiciones concretas.
    private func derivedStats(from attempts: [HintAttempt]) -> DerivedStats? {
        guard !attempts.isEmpty else {
            return nil
        }
        
        let hits = attempts.map { $0.good + $0.fair }
        let bestHit = hits.max() ?? 0
        let bestAttemptIndex = (hits.firstIndex(of: bestHit) ?? 0) + 1
        
        let repeatedCount = attempts.filter { $0.isRepeated }.count
        
        let poorStreak = attempts.reversed().prefix(while: { $0.isPoor }).count
        
        let last3Trend: String
        if hits.count >= 3 {
            let lastThree = Array(hits.suffix(3))
            if lastThree[0] < lastThree[1] && lastThree[1] < lastThree[2] {
                last3Trend = "subiendo"
            } else if lastThree[0] > lastThree[1] && lastThree[1] > lastThree[2] {
                last3Trend = "bajando"
            } else {
                last3Trend = "mixto"
            }
        } else {
            last3Trend = "insuficiente"
        }
        
        let newDigitsRate: Int
        if attempts.count >= 2 {
            let last = attempts[attempts.count - 1].guess
            let previous = attempts[attempts.count - 2].guess
            let lastSet = Set(last)
            let previousSet = Set(previous)
            newDigitsRate = lastSet.subtracting(previousSet).count
        } else {
            newDigitsRate = 0
        }
        
        return DerivedStats(
            bestHit: bestHit,
            bestAttemptIndex: bestAttemptIndex,
            last3Trend: last3Trend,
            repeatedCount: repeatedCount,
            poorStreak: poorStreak,
            newDigitsRate: newDigitsRate
        )
    }
    
    // MARK: - Output Validation (Guardrails)
    
    /// Valida que la salida del modelo NO viole las reglas del juego.
    ///
    /// # Guardrails implementados
    /// 1. **No revelar 5 dígitos consecutivos**: detecta patrones tipo "12345" que podrían ser el secreto.
    /// 2. **No múltiples candidatos**: detecta cuando aparecen 2 o más números de 5 dígitos (listas de soluciones).
    /// 3. **No frases de respuesta directa**: detecta "el número es", "la respuesta es", "es 12345", etc.
    /// 4. **No dígito + posición**: evita instrucciones demasiado directas (ej: "7 en la posición 3").
    /// 5. **No lenguaje tipo solver**: detecta frases que enumeren combinaciones o candidatos posibles.
    ///
    /// # Por qué estos guardrails
    /// - Los modelos de IA pueden "escapar" de las instrucciones del prompt si no hay validación.
    /// - Estos checks protegen la integridad del juego (no revelar el secreto).
    /// - Preferimos una pista no disponible a una pista que rompe el juego.
    ///
    /// # Falsos positivos aceptables
    /// - Es posible que una pista legítima sea rechazada si menciona 5 dígitos por casualidad
    ///   (ej: "probá combinaciones de 1, 2, 3, 4 y 5 en distintas posiciones").
    /// - Esto es un trade-off aceptable: preferimos ser conservadores.
    ///
    /// - Parameter text: salida del modelo de IA.
    /// - Returns: `true` si la salida es segura, `false` si viola guardrails.
    // MARK: - Guardrails: constantes

    /// Longitud máxima del output. Una pista es breve (1-4 líneas); un texto largo
    /// sugiere volcado de candidatos o explicaciones que pueden filtrar información.
    private static let maxOutputLength = 600

    /// Palabras-número (es/en) para detectar el secreto escrito con letras.
    private static let numberWords: Set<String> = [
        "cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"
    ]

    /// Patrones de dígito + posición (demasiado directos, actúan como "resolver").
    /// - Note: se evalúan sobre texto normalizado (minúsculas y sin acentos), por eso
    ///   los patrones usan formas sin tilde (p. ej. `posicion`).
    private static let digitPositionPatterns = [
        #"\b\d\b.{0,12}\b(posicion|pos|lugar)\s*(\d|1ra|2da|3ra|4ta|5ta|primera|segunda|tercera|cuarta|quinta)\b"#,
        #"\b(posicion|pos|lugar)\s*(\d|1ra|2da|3ra|4ta|5ta|primera|segunda|tercera|cuarta|quinta)\b.{0,12}\b\d\b"#,
        #"\b\d\b.{0,12}\b(en\s+la|en\s+el)\s+(1ra|2da|3ra|4ta|5ta|primera|segunda|tercera|cuarta|quinta)\b"#,
        #"\b(en\s+la|en\s+el)\s+(1ra|2da|3ra|4ta|5ta|primera|segunda|tercera|cuarta|quinta)\b.{0,12}\b\d\b"#
    ]

    /// Frases de respuesta directa (ya normalizadas: minúsculas, sin acentos).
    private static let directAnswerPhrases = [
        "el numero es", "la respuesta es", "el secreto es", "es el",
        "prueba este:", "proba este:", "intenta este:"
    ]

    /// Lenguaje tipo solver / enumeración de candidatos (normalizado, sin acentos).
    private static let solverLanguagePhrases = [
        "combinaciones posibles son", "lista de numeros", "posibles numeros son",
        "las opciones son", "todas las combinaciones", "enumerar numeros",
        "voy a enumerar las opciones", "los candidatos principales",
        "posibles numeros incluyen", "los posibles numeros incluyen",
        "prueba estas", "proba estas", "intenta estas", "cualquier orden de estos"
    ]

    /// Normaliza el texto antes de validar: minúsculas, sin acentos y espacios colapsados.
    /// - Why: cierra bypass triviales como "El Número Es" (mayúsculas) o "el numero es"
    ///   (sin tilde), y colapsa dobles espacios/saltos de línea.
    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// Valida que la salida del modelo NO viole las reglas del juego.
    ///
    /// # Filosofía
    /// - Reglas simples, testeables y explicables (no un parser gigante).
    /// - Conservador: preferimos una pista no disponible a una que rompe el juego.
    /// - Se aplica sobre el TEXTO FINAL concatenado (todos los campos del `@Generable`),
    ///   por eso el conteo de dígitos detecta también dígitos repartidos entre campos.
    ///
    /// - Parameter text: salida del modelo (o del fallback).
    /// - Returns: `true` si es segura, `false` si viola guardrails.
    func isOutputSafe(_ text: String) -> Bool {
        // Cap de longitud: una pista es breve; un texto largo huele a volcado de candidatos.
        guard text.count <= Self.maxOutputLength else { return false }

        let normalized = Self.normalize(text)

        // Regla de dígitos: contamos TODOS los dígitos sin importar separadores, saltos
        // de línea o campos. 5 o más ⇒ posible revelación del secreto, ya sea completo
        // ("12345"), con separadores ("1 2 3 4 5", "1-2-3-4-5") o repartido entre campos.
        if text.filter(\.isNumber).count >= GameConstants.secretLength {
            return false
        }

        // Secreto escrito en palabras: "uno dos tres cuatro cinco" / "one two three...".
        let words = normalized.split { !$0.isLetter }.map(String.init)
        if words.filter(Self.numberWords.contains).count >= GameConstants.secretLength {
            return false
        }

        // Frases de respuesta directa (preceden revelaciones del secreto).
        for phrase in Self.directAnswerPhrases where normalized.contains(phrase) {
            return false
        }

        // Dígito + posición (demasiado directo, actúa como "resolver").
        for pattern in Self.digitPositionPatterns where normalized.range(of: pattern, options: .regularExpression) != nil {
            return false
        }

        // Lenguaje tipo solver / enumeración de candidatos.
        for phrase in Self.solverLanguagePhrases where normalized.contains(phrase) {
            return false
        }

        return true
    }
}
