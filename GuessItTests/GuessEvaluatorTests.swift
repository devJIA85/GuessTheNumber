//
//  GuessEvaluatorTests.swift
//  GuessItTests
//
//  Tests puros y directos del scoring del dominio (Good / Fair / Poor).
//  No dependen de SwiftData ni de la UI: GuessEvaluator es 100% puro.
//

import Testing
@testable import GuessIt

@Suite("GuessEvaluator - scoring Good/Fair/Poor")
struct GuessEvaluatorTests {

    // MARK: - Juego normal (5 dígitos)

    @Test("Guess exacto: 5 Good, 0 Fair, no Poor")
    func exactMatch() throws {
        // El guess es idéntico al secreto: todos los dígitos en su posición.
        let result = try GuessEvaluator.evaluate(secret: "01234", guess: "01234")
        #expect(result.good == 5, "Los 5 dígitos están en la posición correcta")
        #expect(result.fair == 0, "No debe haber Fair cuando todo es Good")
        #expect(result.isPoor == false, "No es Poor porque hay matches")
    }

    @Test("Dígitos correctos en posición incorrecta: 0 Good, 5 Fair")
    func allDigitsWrongPosition() throws {
        // "12340" es una rotación de "01234": mismos dígitos, ninguno en su lugar.
        let result = try GuessEvaluator.evaluate(secret: "01234", guess: "12340")
        #expect(result.good == 0, "Ningún dígito coincide en posición")
        #expect(result.fair == 5, "Los 5 dígitos existen pero mal ubicados")
        #expect(result.isPoor == false, "Hay matches (Fair), por lo tanto no es Poor")
    }

    @Test("Mezcla de Good y Fair")
    func mixedGoodAndFair() throws {
        // secret 0,1,2,3,4  guess 0,2,1,4,3
        // pos0: 0==0 Good; el resto son dígitos correctos mal ubicados -> Fair.
        let result = try GuessEvaluator.evaluate(secret: "01234", guess: "02143")
        #expect(result.good == 1, "Solo el dígito 0 está en su posición")
        #expect(result.fair == 4, "Los otros 4 dígitos existen pero desubicados")
        #expect(result.isPoor == false)
    }

    @Test("Mezcla de Good, Fair y dígitos ausentes (isPoor sigue en false)")
    func mixedWithAbsentDigits() throws {
        // secret 0,1,2,3,4  guess 0,2,5,6,7
        // pos0 Good (0); el 2 existe pero desubicado -> Fair; 5,6,7 no están en el secreto.
        let result = try GuessEvaluator.evaluate(secret: "01234", guess: "02567")
        #expect(result.good == 1, "Solo el 0 está en posición")
        #expect(result.fair == 1, "Solo el 2 aporta Fair; 5/6/7 no pertenecen al secreto")
        #expect(result.isPoor == false, "isPoor es false porque Good+Fair > 0")
    }

    @Test("Sin coincidencias: 0 Good, 0 Fair, isPoor == true")
    func noMatchesIsPoor() throws {
        // Ningún dígito de "56789" está en "01234".
        let result = try GuessEvaluator.evaluate(secret: "01234", guess: "56789")
        #expect(result.good == 0)
        #expect(result.fair == 0)
        #expect(result.isPoor == true, "Regla del juego: Poor solo cuando Good+Fair == 0")
    }

    // MARK: - Robustez del conteo por frecuencia (dígitos repetidos en el guess)

    @Test("Dígitos repetidos en el guess no inflan el conteo de Fair")
    func repeatedDigitsDoNotOverCountFair() throws {
        // secret 0,1,2,3,4  guess 1,1,1,1,1
        // El 1 aparece 5 veces en el guess pero una sola vez en el secreto:
        // pos1 es Good; las demás apariciones de 1 NO deben contarse como Fair.
        let result = try GuessEvaluator.evaluate(secret: "01234", guess: "11111")
        #expect(result.good == 1, "Solo la posición 1 coincide")
        #expect(result.fair == 0, "El resto de los '1' no cuentan: el secreto tiene un solo 1")
        #expect(result.isPoor == false)
    }

    @Test("Frecuencia: un dígito repetido en el guess aporta a lo sumo lo que hay en el secreto")
    func frequencyRespectsSecretMultiplicity() throws {
        // secret 0,1,2,3,4  guess 0,5,0,2,1
        // pos0: 0==0 Good (consume el único 0 del secreto).
        // El segundo 0 (pos2) NO debe contar como Fair; el 2 y el 1 sí.
        let result = try GuessEvaluator.evaluate(secret: "01234", guess: "05021")
        #expect(result.good == 1, "El 0 en pos0 es Good")
        #expect(result.fair == 2, "Aportan Fair el 2 y el 1; el segundo 0 no")
        #expect(result.isPoor == false)
    }

    // MARK: - Errores de longitud

    @Test("Guess con longitud inválida lanza EvaluatorError")
    func invalidGuessLengthThrows() {
        #expect(throws: GuessEvaluator.EvaluatorError.self) {
            _ = try GuessEvaluator.evaluate(secret: "01234", guess: "0123")
        }
    }

    @Test("Secret con longitud inválida lanza EvaluatorError")
    func invalidSecretLengthThrows() {
        #expect(throws: GuessEvaluator.EvaluatorError.self) {
            _ = try GuessEvaluator.evaluate(secret: "012", guess: "01234")
        }
    }

    // MARK: - Daily Challenge (3 dígitos)

    @Test("Daily: guess exacto de 3 dígitos = 3 Good")
    func dailyExactMatch() throws {
        let result = try GuessEvaluator.evaluateDailyChallenge(secret: "012", guess: "012")
        #expect(result.good == 3)
        #expect(result.fair == 0)
        #expect(result.isPoor == false)
    }

    @Test("Daily: dígitos correctos mal ubicados = 3 Fair")
    func dailyAllFair() throws {
        let result = try GuessEvaluator.evaluateDailyChallenge(secret: "012", guess: "120")
        #expect(result.good == 0)
        #expect(result.fair == 3)
        #expect(result.isPoor == false)
    }

    @Test("Daily: sin coincidencias = isPoor true")
    func dailyNoMatchesIsPoor() throws {
        let result = try GuessEvaluator.evaluateDailyChallenge(secret: "012", guess: "345")
        #expect(result.good == 0)
        #expect(result.fair == 0)
        #expect(result.isPoor == true)
    }

    @Test("Daily: longitud inválida lanza EvaluatorError")
    func dailyInvalidLengthThrows() {
        #expect(throws: GuessEvaluator.EvaluatorError.self) {
            _ = try GuessEvaluator.evaluateDailyChallenge(secret: "012", guess: "0123")
        }
    }
}
