//
//  HintPromptBuilder.swift
//  GuessIt
//
//  Created by Claude on 06/02/2026.
//

import Foundation

// MARK: - String Extension (regex helper)

/// Extensión privada para contar matches de regex en una string.
/// 
/// # Por qué esta extensión
/// - Swift no provee un método built-in para contar matches de regex.
/// - Necesitamos esta funcionalidad para detectar múltiples candidatos (5 dígitos).
private extension String {
    /// Retorna todas las ocurrencias de un patrón regex en la string.
    ///
    /// - Parameters:
    ///   - pattern: patrón regex.
    ///   - options: opciones de búsqueda (default: []).
    /// - Returns: array de rangos donde se encontró el patrón.
    func ranges(of pattern: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = startIndex..<endIndex
        
        while let range = range(of: pattern, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<endIndex
        }
        
        return ranges
    }
}

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
        // Agregamos un timestamp para forzar variabilidad en el prompt
        let timestamp = Date().timeIntervalSince1970
        sections.append("""
        
        Tu tarea:
        Proporciona UNA pista estratégica breve (1-4 líneas), textual y no determinista.
        
        Varía el tipo de respuesta. Elegí UNO de estos enfoques (alterná entre ellos cuando puedas):
        - Estrategia de posicionamiento: si hay FAIR, sugerí permutar posiciones en lugar de sumar nuevos dígitos.
        - Estrategia de descarte: si hay POOR o dígitos descartados, enfocá el próximo intento en confirmar posiciones.
        - Estrategia de confirmación: si un dígito aparece consistente como FAIR o GOOD, sugerí fijarlo y variar los demás.
        - Estrategia de exploración controlada: cambiar solo un dígito respecto al intento anterior para aislar resultados.
        
        LO QUE PUEDES hacer:
        - Sugerir estrategias generales (permutar posiciones, probar nuevos dígitos, confirmar posiciones conocidas).
        - Recordar patrones del feedback (si hay FAIR, explorar permutaciones; si hay GOOD, fijar esas posiciones).
        - Sugerir reducir el espacio de búsqueda usando la información actual.
        
        LO QUE NO PUEDES hacer:
        - NO revelar el secreto ni dar 5 dígitos consecutivos.
        - NO decir "el número es..." o "la respuesta es...".
        - NO proporcionar un único intento específico como solución final.
        - NO usar lenguaje de solver ni enumerar combinaciones.
        
        Responde SOLO con la pista, sin preámbulos ni explicaciones adicionales.
        
        [Request ID: \(Int(timestamp))]
        """)
        
        return sections.joined(separator: "\n\n")
    }
    
    // MARK: - Output Validation (Guardrails)
    
    /// Valida que la salida del modelo NO viole las reglas del juego.
    ///
    /// # Guardrails implementados
    /// 1. **No revelar 5 dígitos consecutivos**: detecta patrones tipo "12345" que podrían ser el secreto.
    /// 2. **No múltiples candidatos**: detecta cuando aparecen 2 o más números de 5 dígitos (listas de soluciones).
    /// 3. **No frases de respuesta directa**: detecta "el número es", "la respuesta es", "es 12345", etc.
    /// 4. **No lenguaje tipo solver**: detecta frases que enumeren combinaciones o candidatos posibles.
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
    func isOutputSafe(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Guardrail 1: detectar 5 dígitos consecutivos (posible secreto revelado)
        // Regex: \b\d{5}\b → palabra completa de exactamente 5 dígitos
        let fiveDigitsPattern = #"\b\d{5}\b"#
        if let _ = lowercased.range(of: fiveDigitsPattern, options: .regularExpression) {
            return false
        }
        
        // Guardrail 2: detectar múltiples candidatos (listas de 5 dígitos)
        // Por qué: una lista de "candidatos" puede revelar el secreto por reducción
        // Ejemplo bloqueado: "Probá 12345 o 54321"
        let fiveDigitsMatches = text.ranges(of: #"\b\d{5}\b"#, options: .regularExpression)
        if fiveDigitsMatches.count >= 2 {
            return false
        }
        
        // Guardrail 3: detectar frases de respuesta directa
        // Por qué: estas frases suelen preceder revelaciones del secreto
        let directAnswerPhrases = [
            "el número es",
            "la respuesta es",
            "el secreto es",
            "es el",
            "prueba este:",
            "probá este:",
            "intenta este:",
            "intentá este:"
        ]
        
        for phrase in directAnswerPhrases {
            if lowercased.contains(phrase) {
                return false
            }
        }
        
        // Guardrail 4: detectar lenguaje tipo solver / enumeración de candidatos
        // Por qué: estas frases indican que el modelo está intentando resolver el juego
        // en lugar de dar pistas estratégicas, o puede revelar el secreto por reducción
        // Nota: removimos algunas frases genéricas para reducir falsos positivos
        let solverLanguagePhrases = [
            "combinaciones posibles son",
            "lista de números",
            "posibles números son",
            "las opciones son:",
            "todas las combinaciones",
            "enumerar números",
            "prueba estas:",
            "probá estas:",
            "intentá estas:",
            "intenta estas:",
            "cualquier orden de estos"
        ]
        
        for phrase in solverLanguagePhrases {
            if lowercased.contains(phrase) {
                return false
            }
        }
        
        return true
    }
}
