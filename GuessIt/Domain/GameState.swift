//
//  GameState.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// Representa el estado global de una partida.
///
/// # Diseño
/// - Es un `enum` puro (sin lógica ni efectos secundarios).
/// - Define un contrato claro para la UI y el motor de juego.
/// - Facilita persistencia (por ser `Codable`) y evita estados inválidos.
enum GameState: String, Codable, CaseIterable {

    /// La partida está activa y acepta intentos.
    case inProgress

    /// La partida terminó exitosamente (el usuario adivinó el número).
    case won

    /// La partida fue abandonada explícitamente por el usuario.
    case abandoned
}
