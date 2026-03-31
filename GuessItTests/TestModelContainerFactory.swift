//
//  TestModelContainerFactory.swift
//  GuessItTests
//
//  Created by Codex on 31/03/2026.
//

import Foundation
@preconcurrency import SwiftData
@testable import GuessIt

/// Factoría de contenedores SwiftData aislados para tests.
///
/// # Por qué existe
/// - `ModelConfiguration(isStoredInMemoryOnly: true)` sin nombre explícito puede
///   terminar compartiendo identidad entre suites o corridas concurrentes.
/// - Para PR 2 queremos fixtures totalmente aislados, sin tocar la factoría de producción.
enum TestModelContainerFactory {

    /// Crea un `ModelContainer` in-memory con nombre único por invocación.
    ///
    /// - Important: El nombre único fuerza un store efímero independiente para cada test,
    ///   reduciendo contaminación entre suites paralelas o reruns dentro del mismo proceso.
    static func makeIsolatedInMemoryContainer() -> ModelContainer {
        let schema = Schema([
            Game.self,
            Attempt.self,
            DigitNote.self,
            GameStats.self,
            DailyChallenge.self
        ])

        let configuration = ModelConfiguration(
            "GuessItTests.\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear un ModelContainer aislado para tests: \(error)")
        }
    }
}
