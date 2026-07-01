//
//  SecretGeneratorTests.swift
//  GuessItTests
//
//  Tests de generación de secretos. Se usa SeededRandomNumberGenerator para
//  obtener resultados DETERMINISTAS: los tests no dependen del azar del sistema.
//

import Testing
@testable import GuessIt

@Suite("SecretGenerator - generación de secretos")
struct SecretGeneratorTests {

    // MARK: - Invariantes estructurales (juego normal)

    @Test("Genera exactamente 5 dígitos")
    func generatesExpectedLength() {
        // Aunque use el RNG del sistema, la longitud es invariante del dominio.
        let secret = SecretGenerator.generate()
        #expect(secret.count == GameConstants.secretLength)
    }

    @Test("No genera dígitos repetidos")
    func generatesUniqueDigits() {
        // Regla del juego: dígitos únicos. Verificable sin depender del valor exacto.
        let secret = SecretGenerator.generate()
        #expect(Set(secret).count == secret.count, "Todos los dígitos deben ser distintos")
    }

    @Test("Solo produce dígitos 0–9")
    func generatesOnlyValidDigits() {
        let secret = SecretGenerator.generate()
        let allDigits = secret.allSatisfy { $0.isNumber }
        #expect(allDigits, "El secreto solo debe contener dígitos")
    }

    // MARK: - Determinismo con SeededRandomNumberGenerator

    @Test("Con el mismo seed, el secreto es idéntico (determinista)")
    func sameSeedProducesSameSecret() {
        // Dos generadores independientes con el mismo seed deben producir el mismo secreto.
        var rngA = SeededRandomNumberGenerator(seed: 42)
        var rngB = SeededRandomNumberGenerator(seed: 42)
        let secretA = SecretGenerator.generate(using: &rngA)
        let secretB = SecretGenerator.generate(using: &rngB)
        #expect(secretA == secretB, "Mismo seed -> mismo secreto")
        // Y sigue cumpliendo las invariantes del dominio.
        #expect(secretA.count == GameConstants.secretLength)
        #expect(Set(secretA).count == secretA.count)
    }

    @Test("Seeds distintos producen secretos distintos (chequeo determinista, no probabilístico)")
    func differentSeedsProduceDifferentSecrets() {
        // Recolectamos secretos para varios seeds fijos. Como el RNG es determinista,
        // este conjunto es fijo entre ejecuciones: no es un test de azar.
        // Solo colapsaría a 1 si TODOS los seeds dieran el mismo secreto (imposible en la práctica).
        var secrets = Set<String>()
        for seed in UInt64(1)...UInt64(8) {
            var rng = SeededRandomNumberGenerator(seed: seed)
            secrets.insert(SecretGenerator.generate(using: &rng))
        }
        #expect(secrets.count > 1, "Distintos seeds deben producir más de un secreto")
    }

    // MARK: - Daily Challenge (3 dígitos)

    @Test("Daily: genera exactamente 3 dígitos únicos")
    func dailyGeneratesThreeUniqueDigits() {
        let secret = SecretGenerator.generateDailyChallenge()
        #expect(secret.count == GameConstants.dailyChallengeLength)
        #expect(Set(secret).count == secret.count, "Daily también exige dígitos únicos")
    }

    @Test("Daily: con el mismo seed el secreto es idéntico")
    func dailySameSeedProducesSameSecret() {
        var rngA = SeededRandomNumberGenerator(seed: 2026)
        var rngB = SeededRandomNumberGenerator(seed: 2026)
        let secretA = SecretGenerator.generateDailyChallenge(using: &rngA)
        let secretB = SecretGenerator.generateDailyChallenge(using: &rngB)
        #expect(secretA == secretB, "Mismo seed -> mismo secreto diario")
        #expect(secretA.count == GameConstants.dailyChallengeLength)
    }
}
