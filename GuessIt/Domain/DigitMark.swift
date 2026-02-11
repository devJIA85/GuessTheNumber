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

    // MARK: - Cycling

    /// Orden de rotación para el tablero de deducción manual.
    /// El jugador cicla con tap: unknown → poor → fair → good → unknown.
    private static let cycleOrder: [DigitMark] = [.unknown, .poor, .fair, .good]

    /// Devuelve el siguiente mark en el ciclo de rotación.
    ///
    /// # Orden
    /// `unknown → poor → fair → good → unknown`
    ///
    /// # Por qué vive en el enum
    /// - Centraliza la lógica de cycling que antes estaba duplicada
    ///   en `CollapsibleBoardHeader` y `DigitBoardView`.
    /// - Es lógica de dominio, no de presentación.
    func next() -> DigitMark {
        guard let idx = Self.cycleOrder.firstIndex(of: self) else { return .unknown }
        let nextIndex = Self.cycleOrder.index(after: idx)
        return nextIndex < Self.cycleOrder.endIndex ? Self.cycleOrder[nextIndex] : .unknown
    }
}

