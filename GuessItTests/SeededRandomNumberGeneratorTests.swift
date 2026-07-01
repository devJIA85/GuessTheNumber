//
//  SeededRandomNumberGeneratorTests.swift
//  GuessItTests
//
//  Tests del RNG determinista (SplitMix64) que habilita la generación reproducible.
//  Es la base sobre la que se apoyan los tests deterministas de SecretGenerator.
//

import Testing
@testable import GuessIt

@Suite("SeededRandomNumberGenerator - RNG determinista")
struct SeededRandomNumberGeneratorTests {

    @Test("Mismo seed produce la misma secuencia de valores")
    func sameSeedProducesSameSequence() {
        // Dos generadores con igual seed deben emitir exactamente la misma secuencia.
        var a = SeededRandomNumberGenerator(seed: 12345)
        var b = SeededRandomNumberGenerator(seed: 12345)
        let seqA = (0..<10).map { _ in a.next() }
        let seqB = (0..<10).map { _ in b.next() }
        #expect(seqA == seqB, "El RNG debe ser reproducible con el mismo seed")
    }

    @Test("Seeds distintos producen secuencias distintas")
    func differentSeedsProduceDifferentSequences() {
        var a = SeededRandomNumberGenerator(seed: 1)
        var b = SeededRandomNumberGenerator(seed: 2)
        let seqA = (0..<10).map { _ in a.next() }
        let seqB = (0..<10).map { _ in b.next() }
        #expect(seqA != seqB, "Seeds distintos no deberían coincidir en 10 valores")
    }

    @Test("Seed 0 se sanea y produce una secuencia no trivial")
    func zeroSeedIsSanitized() {
        // El init reemplaza el estado 0 por una constante para mejorar la dispersión.
        // Verificamos que no se quede atascado devolviendo siempre 0.
        var rng = SeededRandomNumberGenerator(seed: 0)
        let values = (0..<5).map { _ in rng.next() }
        #expect(values.contains { $0 != 0 }, "El seed 0 no debe degenerar en ceros")
    }
}
