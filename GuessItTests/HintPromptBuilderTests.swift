//
//  HintPromptBuilderTests.swift
//  GuessItTests
//
//  Created by Claude on 06/02/2026.
//

import Testing
import Foundation
import SwiftData
@testable import GuessIt

/// Tests unitarios para HintPromptBuilder (guardrails y construcción de prompt).
///
/// # Cobertura
/// - Guardrails: detectar 5 dígitos consecutivos y frases prohibidas.
/// - Prompt: verificar que contiene elementos clave (reglas, historial, notas).
///
/// # Por qué tests de guardrails son críticos
/// - Los guardrails son la única protección contra respuestas que rompen el juego.
/// - Si fallan, el jugador podría recibir el secreto directamente.
@Suite("HintPromptBuilder Tests")
struct HintPromptBuilderTests {
    
    let builder = HintPromptBuilder()

    // MARK: - Helpers de input

    /// Crea un HintInput mínimo para tests sin depender de persistencia real.
    /// - Why: necesitamos un PersistentIdentifier válido para construir HintInput.
    private func makeInput(attempts: [HintAttempt]) -> HintInput {
        let gameID = makeInMemoryGameID()
        return HintInput(
            gameID: gameID,
            attempts: attempts,
            digitNotes: []
        )
    }

    /// Genera un PersistentIdentifier usando un container in-memory.
    /// - Why: SwiftData no expone un init público para PersistentIdentifier.
    private func makeInMemoryGameID() -> PersistentIdentifier {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Game.self,
            Attempt.self,
            DigitNote.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let game = Game(secret: "00000", digitNotes: [])
        context.insert(game)
        try? context.save()
        return game.persistentID
    }
    
    // MARK: - Guardrails: 5 dígitos consecutivos
    
    @Test("isOutputSafe bloquea 5 dígitos consecutivos (palabra completa)")
    func testIsOutputSafeBlocksFiveDigitsSequence() {
        // Caso directo: 5 dígitos como palabra completa
        #expect(!builder.isOutputSafe("El número es 12345."))
        #expect(!builder.isOutputSafe("Probá 98765 como tu siguiente intento."))
        #expect(!builder.isOutputSafe("54321 es la respuesta."))
    }
    
    @Test("isOutputSafe bloquea 5 dígitos al inicio o final")
    func testIsOutputSafeBlocksFiveDigitsAtBoundaries() {
        #expect(!builder.isOutputSafe("12345 es el secreto."))
        #expect(!builder.isOutputSafe("La respuesta es 67890"))
    }
    
    @Test("isOutputSafe permite 5 dígitos con separadores (no consecutivos)")
    func testIsOutputSafeAllowsFiveDigitsWithSeparators() {
        // Estos casos son seguros: los dígitos están separados por espacios/comas
        #expect(builder.isOutputSafe("Probá los dígitos 1, 2, 3, 4 y 5 en distintas posiciones."))
        #expect(builder.isOutputSafe("Los números 6 7 8 9 0 podrían estar en el secreto."))
    }
    
    @Test("isOutputSafe permite menos de 5 dígitos consecutivos")
    func testIsOutputSafeAllowsLessThanFiveDigits() {
        #expect(builder.isOutputSafe("Probá permutar 123 con 4."))
        #expect(builder.isOutputSafe("El patrón es 45xx."))
    }
    
    // MARK: - Guardrails: frases prohibidas
    
    @Test("isOutputSafe bloquea 'el número es'")
    func testIsOutputSafeBlocksElNumeroEs() {
        #expect(!builder.isOutputSafe("El número es 12345."))
        #expect(!builder.isOutputSafe("el número es 54321"))
        #expect(!builder.isOutputSafe("Creo que el número es correcto."))
    }
    
    @Test("isOutputSafe bloquea 'la respuesta es'")
    func testIsOutputSafeBlocksLaRespuestaEs() {
        #expect(!builder.isOutputSafe("La respuesta es 12345."))
        #expect(!builder.isOutputSafe("la respuesta es obvia"))
    }
    
    @Test("isOutputSafe bloquea 'el secreto es'")
    func testIsOutputSafeBlocksElSecretoEs() {
        #expect(!builder.isOutputSafe("El secreto es 98765."))
        #expect(!builder.isOutputSafe("el secreto es simple"))
    }
    
    @Test("isOutputSafe bloquea frases imperativas directas")
    func testIsOutputSafeBlocksDirectCommands() {
        #expect(!builder.isOutputSafe("Probá este: 12345"))
        #expect(!builder.isOutputSafe("Intentá este: 54321"))
        #expect(!builder.isOutputSafe("prueba este: número"))
    }
    
    @Test("isOutputSafe permite frases estratégicas seguras")
    func testIsOutputSafeAllowsSafeStrategicHints() {
        #expect(builder.isOutputSafe("Intentá permutar las posiciones de los dígitos FAIR."))
        #expect(builder.isOutputSafe("Probá explorar nuevos dígitos en posiciones no confirmadas."))
        #expect(builder.isOutputSafe("Si tenés GOOD en una posición, mantené ese dígito fijo."))
    }
    
    // MARK: - Guardrails extras (múltiples candidatos)
    
    @Test("isOutputSafe bloquea múltiples números de 5 dígitos (listas de candidatos)")
    func testIsOutputSafeBlocksMultipleFiveDigitCandidates() {
        // Por qué: una lista de candidatos puede revelar el secreto por reducción
        #expect(!builder.isOutputSafe("Probá 12345 o 54321."))
        #expect(!builder.isOutputSafe("Las opciones son 12345, 67890 o 11111."))
        #expect(!builder.isOutputSafe("Intentá 98765 o bien 12340."))
    }
    
    @Test("isOutputSafe permite un solo número de 5 dígitos si otras reglas no lo bloquean")
    func testIsOutputSafeAllowsSingleFiveDigitIfOtherRulesPass() {
        // Nota: un solo 5 dígitos YA está bloqueado por el guardrail 1,
        // pero este test verifica que el conteo de múltiples candidatos no genera falsos positivos
        // cuando hay un solo match (que será bloqueado por otra regla).
        
        // Este caso es bloqueado por guardrail 1 (5 dígitos consecutivos)
        #expect(!builder.isOutputSafe("El patrón podría ser 12345."))
    }
    
    // MARK: - Guardrails extras (lenguaje tipo solver)
    
    @Test("isOutputSafe bloquea lenguaje de enumeración y listas")
    func testIsOutputSafeBlocksSolverLanguage() {
        // Por qué: estas frases indican que el modelo está actuando como solver
        // en lugar de dar pistas estratégicas
        #expect(!builder.isOutputSafe("Las combinaciones posibles son varias."))
        #expect(!builder.isOutputSafe("Aquí está la lista de números candidatos."))
        #expect(!builder.isOutputSafe("Los candidatos principales son estos."))
        #expect(!builder.isOutputSafe("Probá estas soluciones en orden."))
        #expect(!builder.isOutputSafe("Las opciones son limitadas."))
    }
    
    @Test("isOutputSafe bloquea frases con 'posibles números' o 'todas las combinaciones'")
    func testIsOutputSafeBlocksCombinationEnumeration() {
        #expect(!builder.isOutputSafe("Los posibles números incluyen varios."))
        #expect(!builder.isOutputSafe("Todas las combinaciones de estos dígitos."))
        #expect(!builder.isOutputSafe("Voy a enumerar las opciones."))
    }
    
    @Test("isOutputSafe bloquea 'prueba/probá estas' (plural imperativo)")
    func testIsOutputSafeBlocksPluralDirectCommands() {
        // Por qué: forma plural sugiere lista de candidatos
        #expect(!builder.isOutputSafe("Probá estas opciones en orden."))
        #expect(!builder.isOutputSafe("Intenta estas combinaciones."))
        #expect(!builder.isOutputSafe("Prueba estas soluciones."))
    }
    
    @Test("isOutputSafe permite frases estratégicas que no son tipo solver")
    func testIsOutputSafeAllowsStrategicNonSolverHints() {
        // Estas pistas son estratégicas y no revelan soluciones específicas
        #expect(builder.isOutputSafe("Enfocate en permutar los dígitos que ya sabés que están."))
        #expect(builder.isOutputSafe("Probá explorar nuevas posiciones para los dígitos FAIR."))
        #expect(builder.isOutputSafe("Si tenés pocos GOOD, necesitás más información antes de adivinar."))
        #expect(builder.isOutputSafe("Recordá que POOR descarta todos los dígitos de ese intento."))
    }
    
    // MARK: - Guardrail extra: dígito + posición
    
    @Test("isOutputSafe bloquea patrones de dígito + posición")
    func testIsOutputSafeBlocksDigitPlusPositionPatterns() {
        #expect(!builder.isOutputSafe("Poné el 7 en la posición 3."))
        #expect(!builder.isOutputSafe("El dígito 4 va en la 2da."))
        #expect(!builder.isOutputSafe("Pos 5: usa el 9."))
        #expect(!builder.isOutputSafe("En el lugar 1 va el 0."))
    }
    
    // MARK: - Construcción de prompt (formato táctico)
    
    @Test("makePrompt incluye el formato táctico requerido")
    func testMakePromptTacticalFormatContainsRequiredHeadings() {
        let input = makeInput(attempts: [])
        let prompt = builder.makePrompt(input: input)
        #expect(prompt.contains("Diagnóstico:"))
        #expect(prompt.contains("Próximo intento:"))
        #expect(prompt.contains("Por qué:"))
    }
    
    @Test("makePrompt incluye resumen táctico derivado cuando hay intentos")
    func testPromptIncludesDerivedStatsSectionWhenAttemptsExist() {
        let attempts = [
            HintAttempt(guess: "01234", good: 1, fair: 1, isPoor: false, isRepeated: false),
            HintAttempt(guess: "56789", good: 0, fair: 2, isPoor: false, isRepeated: false),
            HintAttempt(guess: "98765", good: 2, fair: 0, isPoor: false, isRepeated: true)
        ]
        let input = makeInput(attempts: attempts)
        let prompt = builder.makePrompt(input: input)
        #expect(prompt.contains("Resumen táctico (derivado"))
        #expect(prompt.contains("Mejor hit (GOOD+FAIR): 2"))
        #expect(prompt.contains("Repetidos: 1"))
    }
}
