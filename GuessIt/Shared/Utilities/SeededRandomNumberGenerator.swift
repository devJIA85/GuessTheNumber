//
//  SeededRandomNumberGenerator.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import Foundation

/// Generador RNG determinístico basado en SplitMix64.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Evita estado 0 para mejorar la dispersión inicial.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
