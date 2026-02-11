//
//  GameDetailView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI
import SwiftData

/// Pantalla de detalle de una partida terminada.
///
/// # Rol
/// - Muestra el resumen completo de una partida cerrada (won o abandoned).
/// - Carga datos usando snapshots Sendable (no cruza objetos @Model).
/// - Vista de solo lectura: no persiste ni muta datos.
///
/// # Fuente de verdad
/// - Recibe un `GameIdentifier` y carga el snapshot desde `GuessItModelActor`.
/// - No usa @Query ni objetos @Model: respeta aislamiento de SwiftData.
struct GameDetailView: View {

    // MARK: - Input

    /// Identificador de la partida a mostrar.
    let gameID: GameIdentifier
    
    // MARK: - Dependencies
    
    @Environment(\.appEnvironment) private var env
    
    // MARK: - Estado de carga
    
    /// Estado de carga del detalle de la partida.
    @State private var state: LoadState<GameDetailSnapshot> = .loading

    var body: some View {
        ZStack {
            // SwiftUI 2025: Usar PremiumBackgroundGradient + backgroundExtensionEffect
            PremiumBackgroundGradient()
                .modernBackgroundExtension()

            Group {
                switch state {
                case .loading:
                    ProgressView("Cargando detalle...")
                        .tint(.appActionPrimary)
                case .loaded(let snapshot):
                    detailContent(snapshot: snapshot)
                case .empty:
                    // Este caso no debería ocurrir en la práctica (una partida siempre existe si llegamos aquí)
                    emptyStateView
                case .failure(let error):
                    failureView(error: error)
                }
            }
        }
        .navigationTitle("Detalle de partida")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: gameID) {
            await loadGameDetail()
        }
    }
    
    // MARK: - Data Loading
    
    /// Carga el detalle de la partida desde el actor.
    private func loadGameDetail() async {
        do {
            let snapshot = try await env.modelActor.fetchGameDetailSnapshot(gameID: gameID)
            state = LoadState.loaded(snapshot)
        } catch {
            state = LoadState.failure(error)
        }
    }
    
    /// Vista de error con opción de reintentar.
    private func failureView(error: Error) -> some View {
        VStack(spacing: 16) {
            Text("No se pudo cargar la partida.")
                .font(.headline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Reintentar") {
                Task(name: "RetryLoadGameDetail") {
                    await loadGameDetail()
                }
            }
            .modernProminentButton()  // SwiftUI 2025: Liquid Glass button
            .tint(.appActionPrimary)
        }
        .padding()
    }
    
    /// Vista cuando no se encuentra la partida.
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("No se encontró la partida.")
                .font(.headline)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding()
    }
    
    /// Contenido principal del detalle.
    ///
    /// # Liquid Glass (WWDC25: Adopting Liquid Glass)
    /// - Removido `.background(Color.appBackgroundPrimary)` que bloqueaba el
    ///   `PremiumBackgroundGradient` y el efecto glass nativo del List.
    /// - `.scrollContentBackground(.hidden)` es suficiente para que el gradiente
    ///   premium sea visible a través de las secciones glass del List.
    private func detailContent(snapshot: GameDetailSnapshot) -> some View {
        List {
            headerSection(snapshot: snapshot)
            attemptsSection(snapshot: snapshot)
            digitBoardSection(snapshot: snapshot)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Header

    /// Sección superior con resumen de la partida.
    private func headerSection(snapshot: GameDetailSnapshot) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Estado de la partida
                HStack {
                    Text("Estado")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)

                    Spacer()

                    Text(stateText(for: snapshot.state))
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                }

                // Fecha de finalización
                HStack {
                    Text("Fecha")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)

                    Spacer()

                    Text(displayDate(for: snapshot), format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                }

                // Cantidad de intentos
                HStack {
                    Text("Intentos")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)

                    Spacer()

                    Text("\(snapshot.attempts.count)")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                }

                // Número secreto (solo si está ganada, para no spoilear)
                if let secret = snapshot.secret {
                    HStack {
                        Text("Número secreto")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)

                        Spacer()

                        Text(secret)
                            .font(.headline)
                            .fontDesign(.monospaced)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
        } header: {
            Text("Resumen")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel(for: snapshot))
    }

    // MARK: - Attempts

    /// Sección con la lista completa de intentos.
    /// - Note: los intentos ya vienen ordenados del snapshot (más reciente primero).
    private func attemptsSection(snapshot: GameDetailSnapshot) -> some View {
        Section {
            if snapshot.attempts.isEmpty {
                Text("No hay intentos registrados.")
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(snapshot.attempts) { attemptSnapshot in
                    AttemptRowView(snapshot: attemptSnapshot)
                }
            }
        } header: {
            Text("Intentos (\(snapshot.attempts.count))")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Intentos, lista de \(snapshot.attempts.count) elementos")
    }

    // MARK: - Digit Board

    /// Sección con el tablero final de dígitos (modo solo lectura).
    private func digitBoardSection(snapshot: GameDetailSnapshot) -> some View {
        DigitBoardSnapshotView(digitNotes: snapshot.digitNotes)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tablero final de dígitos")
    }

    // MARK: - Helpers

    /// Texto del estado de la partida.
    private func stateText(for state: GameState) -> String {
        switch state {
        case .won:
            return "Ganada"
        case .abandoned:
            return "Abandonada"
        case .inProgress:
            // No debería aparecer aquí, pero lo manejamos por completitud
            return "En progreso"
        }
    }

    /// Fecha a mostrar.
    ///
    /// - Why: priorizamos `finishedAt` porque representa cuándo terminó realmente.
    ///   Si no existe (casos edge), usamos `createdAt` como fallback.
    private func displayDate(for snapshot: GameDetailSnapshot) -> Date {
        snapshot.finishedAt ?? snapshot.createdAt
    }

    /// Label de accesibilidad para el header.
    private func headerAccessibilityLabel(for snapshot: GameDetailSnapshot) -> String {
        let state = stateText(for: snapshot.state).lowercased()
        let date = displayDate(for: snapshot).formatted(.dateTime.year().month().day().hour().minute())
        let attempts = snapshot.attempts.count
        return "Detalle de partida, \(state), fecha \(date), \(attempts) intentos."
    }
}

#Preview("GameDetailView") {
    // Preview con entorno configurado
    let container = ModelContainerFactory.make(isInMemory: true)
    let env = AppEnvironment(modelContainer: container)
    
    // Crear una partida de ejemplo para el preview
    let game = Game(secret: "12345", digitNotes: [])
    game.state = .won
    game.finishedAt = Date().addingTimeInterval(-86400)
    game.digitNotes = (0...9).map { digit in
        DigitNote(digit: digit, mark: .unknown, game: game)
    }
    container.mainContext.insert(game)
    try? container.mainContext.save()
    
    return NavigationStack {
        GameDetailView(gameID: game.persistentID)
            .environment(\.appEnvironment, env)
            .modelContainer(container)
    }
}
