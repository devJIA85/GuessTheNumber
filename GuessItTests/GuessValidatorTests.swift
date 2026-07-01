//
//  GuessValidatorTests.swift
//  GuessItTests
//
//  Tests directos de la validación de input del dominio.
//  ValidationError es Equatable, por eso podemos afirmar el caso exacto esperado.
//

import Testing
@testable import GuessIt

@Suite("GuessValidator - validación de input")
struct GuessValidatorTests {

    // MARK: - Juego normal (5 dígitos, únicos)

    @Test("Input válido de 5 dígitos únicos no lanza")
    func validInputPasses() throws {
        // No debe lanzar: 5 dígitos, numéricos, en rango y sin repetidos.
        try GuessValidator.validate("01234")
    }

    @Test("Input demasiado corto lanza invalidLength")
    func tooShortThrows() {
        #expect(throws: GuessValidator.ValidationError.invalidLength(expected: 5)) {
            try GuessValidator.validate("0123")
        }
    }

    @Test("Input demasiado largo lanza invalidLength")
    func tooLongThrows() {
        #expect(throws: GuessValidator.ValidationError.invalidLength(expected: 5)) {
            try GuessValidator.validate("012345")
        }
    }

    @Test("Input con caracteres no numéricos lanza nonNumericCharacters")
    func nonNumericThrows() {
        // Longitud correcta (5) pero contiene una letra.
        #expect(throws: GuessValidator.ValidationError.nonNumericCharacters) {
            try GuessValidator.validate("0123a")
        }
    }

    @Test("Input con dígitos repetidos lanza repeatedDigits")
    func repeatedDigitsThrows() {
        // Regla del juego normal: no se permiten dígitos repetidos.
        #expect(throws: GuessValidator.ValidationError.repeatedDigits) {
            try GuessValidator.validate("01230")
        }
    }

    // MARK: - Daily Challenge (3 dígitos, únicos)

    @Test("Daily: input válido de 3 dígitos únicos no lanza")
    func dailyValidInputPasses() throws {
        try GuessValidator.validateDailyChallenge("012")
    }

    @Test("Daily: longitud incorrecta lanza invalidLength(expected: 3)")
    func dailyInvalidLengthThrows() {
        #expect(throws: GuessValidator.ValidationError.invalidLength(expected: 3)) {
            try GuessValidator.validateDailyChallenge("0123")
        }
    }

    @Test("Daily: dígitos repetidos lanza repeatedDigits")
    func dailyRepeatedDigitsThrows() {
        #expect(throws: GuessValidator.ValidationError.repeatedDigits) {
            try GuessValidator.validateDailyChallenge("001")
        }
    }

    @Test("Daily: caracteres no numéricos lanza nonNumericCharacters")
    func dailyNonNumericThrows() {
        #expect(throws: GuessValidator.ValidationError.nonNumericCharacters) {
            try GuessValidator.validateDailyChallenge("01a")
        }
    }
}
