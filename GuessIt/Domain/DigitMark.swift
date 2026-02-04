//
//  DigitMark.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import Foundation

/// Representa el estado de conocimiento del jugador sobre un dígito (0–9).
///
/// # Rol en la arquitectura
/// - Es un **enum de dominio compartido**.
/// - Se utiliza tanto en persistencia (`DigitNote`) como en UI.
/// - No contiene lógica, solo semántica.
///
/// # Orden semántico
/// El orden de los casos no implica jerarquía lógica,
/// solo estados posibles del conocimiento del jugador.
enum DigitMark: String, Codable, CaseIterable {

    /// El dígito aún no fue evaluado o no hay información suficiente.
    case unknown

    /// El dígito es correcto y está en la posición correcta.
    case good

    /// El dígito es correcto pero está en una posición incorrecta.
    case fair

    /// El dígito no pertenece al número secreto.
    case poor
}

