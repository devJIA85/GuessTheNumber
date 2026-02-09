//
//  GameView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI
import SwiftData
import UIKit

/// Pantalla principal del juego.
///
/// # Rol
/// - Es la vista raíz que se monta desde `GuessItApp`.
/// - Consume `GameActor` a través de `AppEnvironment`.
/// - Lee el estado persistido (SwiftData) con `@Query`.
struct GameView: View {

    // MARK: - Dependencies

    /// Acceso al composition root (actores y servicios de alto nivel).
    @Environment(\.appEnvironment) private var env

    // MARK: - SwiftData

    /// Buscamos las partidas recientes ordenadas por fecha de creación.
    /// - Note: filtramos en código (no en el predicado) porque SwiftData tiene limitaciones
    ///   con enums en predicados en runtime.
    @Query(
        sort: [SortDescriptor(\Game.createdAt, order: .reverse)]
    ) private var allGames: [Game]

    // MARK: - UI State

    /// Input del usuario (string crudo).
    @State private var guessText: String = ""

    /// Manejo simple de errores para mostrar en un alert.
    @State private var errorMessage: String?
    
    // MARK: - Hint State
    
    /// Estado de carga de la pista AI.
    @State private var hintState: LoadState<HintOutput> = .empty
    
    /// Controla la presentación del sheet de pista.
    @State private var isHintPresented = false
    
    /// Task de generación de pista (para cancelar si se cierra el sheet).
    @State private var hintTask: Task<Void, Never>?
    
    /// Información de debug de la pista (solo DEBUG).
    ///
    /// # Por qué @State
    /// - Esta info se carga cada vez que se abre el sheet de pista.
    /// - Se actualiza con cada generación de pista.
    @State private var hintDebugInfo: HintDebugInfo? = nil
    
    /// Historial de pistas generadas en la partida actual (memoria local).
    /// - Why: permite mostrar pistas anteriores sin persistirlas en SwiftData.
    @State private var hintHistory: [HintHistoryEntry] = []

    /// Estado observable de la splash de victoria.
    /// - Why: permite coordinar presentación + haptic sin persistencia.
    @State private var victorySplash = VictorySplashState()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.large) {
                        // Input: foco principal de la pantalla
                        // - Why: sin card Estado, el input lidera inmediatamente
                        if let game = currentGame {
                            if game.state == .inProgress {
                                AppCard(title: "Tu intento", style: .standard) {
                                    GuessInputView(guessText: $guessText) { normalized in
                                        submit(normalized)
                                    }
                                }
                            } else {
                                disabledInputCard
                            }
                        } else {
                            AppCard(title: "Tu intento", style: .standard) {
                                GuessInputView(guessText: $guessText) { normalized in
                                    submit(normalized)
                                }
                            }
                        }

                        // Sección de victoria (solo si ganó)
                        if let game = currentGame, game.state == .won {
                            victoryCard(for: game)
                        }

                        // Contenido de la partida: secundario, más compacto
                        if let game = currentGame {
                            attemptsCard(for: game)
                            boardCard(for: game)
                        } else {
                            emptyStateCard
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.vertical, AppTheme.Spacing.medium)
                }
            }
            .overlay {
                if victorySplash.isPresented, let game = currentGame {
                    VictorySplashView(
                        secret: game.secret,
                        attempts: game.attempts.count
                    ) {
                        // Cerramos la splash antes de iniciar nueva partida para evitar flashes.
                        withAnimation(.easeOut(duration: 0.2)) {
                            victorySplash.dismiss()
                        }
                        startNewGame()
                    }
                    // Transición sutil: fade + scale.
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            // Animación sutil para entrada/salida de la splash.
            .animation(.easeOut(duration: 0.2), value: victorySplash.isPresented)
            .navigationTitle("Guess It")
            .navigationSubtitle(statusText)
            .tint(.appActionPrimary)
            .task {
                // Asegurar que siempre hay una partida en progreso al abrir la app
                if currentGame == nil {
                    do {
                        try await env.gameActor.resetGame()
                    } catch {
                        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                }
            }
            .onChange(of: currentGame?.state) { _, newValue in
                if newValue == .won {
                    withAnimation(.easeOut(duration: 0.2)) {
                        victorySplash.present()
                    }
                    triggerVictoryHapticIfNeeded()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        victorySplash.dismiss()
                    }
                    victorySplash.resetHaptic()
                }
                if newValue == .inProgress {
                    // Reiniciamos la pista para evitar contaminación entre partidas o estados.
                    resetHintUIState()
                }
            }
            .onChange(of: currentGame?.id) { _, _ in
                // Cambió la partida activa: limpiamos estado de pista para comenzar desde cero.
                resetHintUIState()
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { errorMessage = nil }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Historial", systemImage: "clock.arrow.circlepath")
                            .labelStyle(.iconOnly)
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
                
                // Botón de pista: solo visible/habilitado si hay partida en progreso
                ToolbarItem(placement: .topBarTrailing) {
                    if let game = currentGame, game.state == .inProgress {
                        Button {
                            // Reiniciamos estado para forzar una nueva generación en cada apertura.
                            prepareHintPresentation()
                            isHintPresented = true
                        } label: {
                            Label("Pista", systemImage: "lightbulb")
                                .labelStyle(.iconOnly)
                        }
                        .foregroundStyle(Color.appTextSecondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewGame()
                    } label: {
                        Label("Reiniciar", systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .sheet(isPresented: $isHintPresented, onDismiss: {
                // Cancelar la task de generación si el usuario cierra el sheet
                hintTask?.cancel()
                hintTask = nil
            }) {
                hintSheet
            }
        }
    }

    // MARK: - Sections

    /// Sección que se muestra cuando no hay partida en progreso todavía.
    private var emptyStateCard: some View {
        AppCard(style: .compact) {
            Text("Aún no hay una partida en progreso. Ingresá tu primer intento para comenzar.")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    /// Sección que reemplaza el input cuando la partida ya terminó.
    /// - Why: evitamos que el usuario intente enviar más intentos en una partida finalizada.
    private var disabledInputCard: some View {
        AppCard(title: "Tu intento", style: .light) {
            Text("La partida ya terminó. Creá una nueva para seguir jugando.")
                .foregroundStyle(Color.appTextSecondary)
                .font(.caption)
        }
    }

    /// Sección de victoria con resumen y CTA para nueva partida.
    /// - Why: proporciona feedback claro al ganar y ofrece un camino evidente
    ///   para continuar jugando sin tener que buscar el botón de reinicio.
    private func victoryCard(for game: Game) -> some View {
        AppCard(title: "Resultado") {
            VStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                Text("¡Ganaste! 🎉")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appTextPrimary)

                VStack(spacing: AppTheme.Spacing.xSmall) {
                    HStack {
                        Text("Secreto:")
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text(game.secret)
                            .fontDesign(.monospaced)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Intentos:")
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text("\(game.attempts.count)")
                            .fontWeight(.semibold)
                    }
                }

                Button {
                    startNewGame()
                } label: {
                    Label("Nueva partida", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appActionPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ganaste. Secreto: \(game.secret). Intentos: \(game.attempts.count).")
    }

    /// Historial de intentos persistidos de la partida actual.
    /// - Why compact: es información secundaria, debe ser escaneable pero no dominar.
    private func attemptsCard(for game: Game) -> some View {
        AppCard(title: "Intentos", style: .compact) {
            let sortedAttempts = game.attempts.sorted { $0.createdAt > $1.createdAt }
            let maxVisibleAttempts = 5
            // Limitamos la altura para que se vean ~5 intentos y el resto quede scrolleable.
            let maxVisibleHeight = CGFloat(maxVisibleAttempts) * 44

            if sortedAttempts.isEmpty {
                Text("Todavía no hay intentos.")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppTheme.Spacing.xSmall)
                    // Damos altura mínima para que la tarjeta no se vea “encogida” sin intentos.
            } else {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.xSmall) {
                        ForEach(sortedAttempts) { attempt in
                            AttemptRowView(attempt: attempt)
                                .padding(AppTheme.Spacing.small)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.appBackgroundSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.appBorderSubtle.opacity(0.5), lineWidth: 0.5)
                                )
                        }
                    }
                }
                // Fijamos altura aproximada para mostrar 4 intentos y permitir scroll interno.
                .frame(maxHeight: maxVisibleHeight)
            }
        }
    }

    /// Tablero 0-9: herramienta de apoyo.
    /// - Why compact: es secundario, no debe dominar la pantalla.
    private func boardCard(for game: Game) -> some View {
        AppCard(style: .compact) {
            DigitBoardView(game: game, isReadOnly: game.state != .inProgress)
        }
    }

    // MARK: - Helpers

    /// La partida actual (en progreso o recién ganada).
    /// - Why: unifica el acceso a la partida activa en toda la vista.
    /// - Note: filtramos abandonadas porque no son relevantes para la vista principal.
    private var currentGame: Game? {
        allGames.first { $0.state != .abandoned }
    }

    /// Texto de estado, basado en la partida persistida.
    private var statusText: String {
        guard let game = currentGame else {
            return "Sin partida"
        }

        switch game.state {
        case .inProgress:
            return "En progreso"
        case .won:
            return "Ganada"
        case .abandoned:
            return "Abandonada"
        }
    }

    /// Inicia una nueva partida.
    /// - Why: resetea el juego y limpia el estado UI local.
    private func startNewGame() {
        // Cerramos la splash antes de resetear para evitar el flash de “ganaste”.
        victorySplash.dismiss()
        
        Task {
            do {
                try await env.gameActor.resetGame()
                guessText = ""
                // Limpiamos cualquier pista previa para que la nueva partida arranque en idle.
                resetHintUIState()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Envía el guess al actor del dominio.
    /// - Note: hacemos `Task` porque cruzamos aislamiento de actor.
    /// - Why no se guarda lastResult: la lista de intentos ya muestra el historial completo.
    private func submit(_ guess: String) {
        Task {
            do {
                _ = try await env.gameActor.submitGuess(guess)
                guessText = ""
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Dispara el haptic de éxito una sola vez por victoria.
    /// - Why: refuerza el feedback sin ser intrusivo.
    private func triggerVictoryHapticIfNeeded() {
        guard !victorySplash.didFireHaptic else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        victorySplash.markHapticFired()
    }
    
    // MARK: - Hint Sheet
    
    /// Vista del sheet de pista.
    ///
    /// # Estados
    /// - loading: generando la pista (muestra spinner diferido).
    /// - loaded: pista disponible (muestra texto).
    /// - failure: error al generar (muestra mensaje de error).
    /// - empty: estado inicial (no debería verse, genera automáticamente).
    private var hintSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundPrimary
                    .ignoresSafeArea()

                Group {
                    switch hintState {
                    case .loading:
                        AppCard(title: "Pista inteligente") {
                            VStack(spacing: AppTheme.Spacing.medium) {
                                // Spinner diferido: evita parpadeos si la pista responde rápido
                                // Por qué 300ms: balance entre evitar flicker y no hacer esperar al usuario
                                // Por qué hintState.isLoading: el spinner debe aparecer/desaparecer según el estado real
                                DeferredProgressView(
                                    isActive: hintState.isLoading,
                                    delay: .milliseconds(300)
                                )
                                .frame(height: 60)
                                
                                Text("Generando pista...")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(AppTheme.Spacing.medium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    case .loaded(let output):
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                                AppCard(title: "Pista inteligente") {
                                    Text(output.text)
                                        .font(.body)
                                        .foregroundStyle(Color.appTextPrimary)
                                        .accessibilityLabel("Pista: \(output.text)")
                                }
                                
                                if hintHistory.count > 1 {
                                    AppCard(title: "Pistas anteriores") {
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                            // Mostramos las pistas previas en orden descendente (mas recientes primero).
                                            ForEach(hintHistory.dropLast().reversed()) { entry in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(entry.title)
                                                        .font(.caption)
                                                        .foregroundStyle(Color.appTextSecondary)
                                                    Text(entry.text)
                                                        .foregroundStyle(Color.appTextPrimary)
                                                }
                                                .accessibilityElement(children: .combine)
                                                .accessibilityLabel("Pista anterior: \(entry.text)")
                                            }
                                        }
                                    }
                                }
                                
                                #if DEBUG
                                // Sección de debug (solo visible en DEBUG builds)
                                if let debugInfo = hintDebugInfo {
                                    AppCard(title: "Debug") {
                                        debugSection(debugInfo)
                                    }
                                }
                                #endif
                            }
                            .padding(AppTheme.Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                    case .failure(let error):
                        AppCard(title: "Pista inteligente") {
                            VStack(spacing: AppTheme.Spacing.medium) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.appTextSecondary)
                                
                                Text(errorMessageForHint(error))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(AppTheme.Spacing.medium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    case .empty:
                        // Estado inicial, trigger generación
                        Color.clear
                            .onAppear {
                                generateHint()
                            }
                    }
                }
            }
            .navigationTitle("Pista Inteligente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        isHintPresented = false
                    }
                }
            }
        }
        .tint(.appActionPrimary)
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Hint Helpers
    
    /// Genera una pista para la partida actual.
    ///
    /// # Flujo
    /// 1. Obtener snapshot de la partida actual.
    /// 2. Convertir snapshot a HintInput.
    /// 3. Llamar HintService.generateHint.
    /// 4. Actualizar hintState con el resultado.
    ///
    /// # Cancelación
    /// - La task se guarda en hintTask para poder cancelarla si se cierra el sheet.
    private func generateHint() {
        // Cancelar task anterior si existe
        hintTask?.cancel()
        
        // Setear estado loading
        hintState = .loading
        
        // Crear nueva task
        hintTask = Task {
            do {
                // 1. Obtener ID de la partida actual
                guard let gameID = try await env.modelActor.fetchInProgressGameID() else {
                    hintState = .failure(HintError.unavailable)
                    return
                }
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 2. Obtener snapshot completo
                let snapshot = try await env.modelActor.fetchGameDetailSnapshot(gameID: gameID)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 3. Convertir snapshot a HintInput
                let hintInput = makeHintInput(from: snapshot)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 4. Generar pista
                let output = try await env.hintService.generateHint(input: hintInput)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 5. Registrar pista en historial local antes de mostrarla.
                hintHistory.append(HintHistoryEntry(text: output.text, createdAt: Date()))
                
                // 6. Actualizar estado (en MainActor)
                hintState = .loaded(output)
                
                // 7. Cargar debug info (solo en DEBUG)
                #if DEBUG
                hintDebugInfo = await env.hintService.debugInfo()
                #endif
                
            } catch is CancellationError {
                // Task fue cancelada, no hacer nada
                return
            } catch {
                // Error al generar pista
                hintState = .failure(error)
            }
        }
    }
    
    /// Resetea el estado de la pista y cancela cualquier generación en curso.
    /// - Why: evita que el texto o loading de una partida anterior contamine la nueva.
    private func resetHintUIState() {
        hintTask?.cancel()
        hintTask = nil
        hintState = .empty
        hintDebugInfo = nil
        hintHistory.removeAll()
        isHintPresented = false
    }

    /// Prepara el estado de la pista para generar una nueva al abrir el sheet.
    /// - Why: si el usuario pide otra pista, no debe quedarse con la anterior.
    private func prepareHintPresentation() {
        hintTask?.cancel()
        hintTask = nil
        hintState = .empty
        hintDebugInfo = nil
    }

    /// Modelo liviano para renderizar historial de pistas en la UI.
    /// - Why: evita depender de SwiftData y mantiene el estado solo en memoria.
    private struct HintHistoryEntry: Identifiable {
        let id = UUID()
        let text: String
        let createdAt: Date

        var title: String {
            // Mostramos una etiqueta simple para darle contexto temporal sin persistencia.
            "Pista \(formattedTime)"
        }

        private var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: createdAt)
        }
    }
    
    /// Convierte un GameDetailSnapshot a HintInput.
    ///
    /// # Por qué este mapper
    /// - HintInput es Sendable y no depende de SwiftData.
    /// - GameDetailSnapshot ya es Sendable y tiene todos los datos necesarios.
    /// - Este mapper mantiene la separación de concerns (UI → DTO → Service).
    private func makeHintInput(from snapshot: GameDetailSnapshot) -> HintInput {
        let attempts = snapshot.attempts.map { attempt in
            HintAttempt(
                guess: attempt.guess,
                good: attempt.good,
                fair: attempt.fair,
                isPoor: attempt.isPoor,
                isRepeated: attempt.isRepeated
            )
        }
        
        let digitNotes = snapshot.digitNotes.map { note in
            HintDigitNote(
                digit: note.digit,
                mark: note.mark
            )
        }
        
        return HintInput(
            gameID: snapshot.id,
            attempts: attempts,
            digitNotes: digitNotes
        )
    }
    
    /// Mapea errores de hint a mensajes user-friendly.
    ///
    /// # Por qué este helper
    /// - Los errores técnicos (HintError) no son buenos mensajes para el usuario.
    /// - Centralizamos la lógica de mensajes en un solo lugar.
    private func errorMessageForHint(_ error: Error) -> String {
        if let hintError = error as? HintError {
            switch hintError {
            case .unavailable:
                return "Las pistas no están disponibles en este dispositivo. Se requiere Apple Intelligence."
            case .generationFailed:
                return "No se pudo generar una pista en este momento. Intentá de nuevo más tarde."
            case .unsafeOutput:
                return "La pista generada no cumplió con las reglas de seguridad. Intentá de nuevo."
            }
        }
        return "Ocurrió un error inesperado al generar la pista."
    }
    
    // MARK: - Debug UI (solo DEBUG)
    
    #if DEBUG
    /// Sección de debug con telemetría del HintService.
    ///
    /// # Por qué solo DEBUG
    /// - Esta info solo es útil para QA y desarrollo.
    /// - No debe mostrarse en Release builds.
    ///
    /// # Contenido
    /// - Total de requests de pistas en esta sesión.
    /// - Engine usado (apple o fallback).
    /// - Último error (si hubo).
    @ViewBuilder
    private func debugSection(_ info: HintDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 8)
            
            Text("Debug Info (solo visible en DEBUG)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appTextSecondary)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Requests:")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("\(info.requestCount)")
                        .font(.caption)
                        .fontDesign(.monospaced)
                }
                
                if let engine = info.lastEngineUsed {
                    HStack {
                        Text("Engine:")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                        Text(engine)
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                }
                
                if let error = info.lastErrorDescription {
                    HStack(alignment: .top) {
                        Text("Last error:")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                        Text(error)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(12)
            .background(Color.appTextSecondary.opacity(0.12))
            .cornerRadius(8)
        }
    }
    #endif
}
