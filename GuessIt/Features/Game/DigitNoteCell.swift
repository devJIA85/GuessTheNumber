//
//  DigitNoteCell.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI

/// Celda individual del tablero 0–9.
///
/// # Rol
/// - Presenta un dígito y su marca actual.
/// - Permite cambiar la marca por tap (ciclo) o por menú contextual.
///
/// # Accesibilidad
/// - No depende solo del color: muestra texto/símbolo + label accesible.
struct DigitNoteCell: View {

    let digit: Int
    let mark: DigitMark

    /// Acción primaria (tap): típicamente “ciclar” la marca.
    let onTap: () -> Void

    /// Acción explícita para setear una marca concreta (context menu).
    let onSetMark: (DigitMark) -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text("\(digit)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    Image(systemName: markSymbol)
                        .font(.subheadline)

                    Text(markShortText)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(markEmphasisStyle)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .contextMenu {
            // Menú explícito: evita obligar al usuario a “ciclar” si quiere un estado específico.
            Button {
                onSetMark(.unknown)
            } label: {
                Label("Sin marca", systemImage: "questionmark.circle")
            }

            Button {
                onSetMark(.poor)
            } label: {
                Label("Descartado (POOR)", systemImage: "xmark.circle")
            }

            Button {
                onSetMark(.fair)
            } label: {
                Label("Presente (FAIR)", systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                onSetMark(.good)
            } label: {
                Label("Confirmado (GOOD)", systemImage: "checkmark.circle")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Doble toque para cambiar la marca. Mantener presionado para elegir una marca específica.")
    }

    // MARK: - Presentation helpers

    private var markSymbol: String {
        switch mark {
        case .unknown: return "questionmark.circle"
        case .poor:    return "xmark.circle"
        case .fair:    return "arrow.triangle.2.circlepath"
        case .good:    return "checkmark.circle"
        }
    }

    /// Texto corto visible (no depender solo del color).
    private var markShortText: String {
        switch mark {
        case .unknown: return "—"
        case .poor:    return "POOR"
        case .fair:    return "FAIR"
        case .good:    return "GOOD"
        }
    }

    /// Estilo “semántico” (sin obligar a interpretar solo por color).
    private var markEmphasisStyle: AnyShapeStyle {
        switch mark {
        case .unknown:
            return AnyShapeStyle(.secondary)
        case .poor:
            return AnyShapeStyle(.secondary) // MVP: neutro; más adelante podemos tintar.
        case .fair:
            return AnyShapeStyle(.primary)
        case .good:
            return AnyShapeStyle(.primary)
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        "Dígito \(digit). Marca: \(markSpokenText)."
    }

    private var markSpokenText: String {
        switch mark {
        case .unknown: return "sin marca"
        case .poor:    return "descartado"
        case .fair:    return "presente pero sin posición confirmada"
        case .good:    return "confirmado"
        }
    }
}

#Preview("DigitNoteCell") {
    List {
        DigitNoteCell(digit: 7, mark: .unknown, onTap: {}, onSetMark: { _ in })
        DigitNoteCell(digit: 3, mark: .poor, onTap: {}, onSetMark: { _ in })
        DigitNoteCell(digit: 1, mark: .fair, onTap: {}, onSetMark: { _ in })
        DigitNoteCell(digit: 9, mark: .good, onTap: {}, onSetMark: { _ in })
    }
}
