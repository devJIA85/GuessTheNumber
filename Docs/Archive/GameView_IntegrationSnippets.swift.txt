//
//  GameView_IntegrationSnippets.swift
//  GuessIt
//
//  Created by Claude on 15/02/2026.
//
//  ESTE ARCHIVO CONTIENE SNIPPETS DE CÓDIGO PARA COPIAR Y PEGAR EN GameView.swift
//  NO COMPILAR - SOLO REFERENCIA

/*

================================================================================
SNIPPET 1: Reemplazar initializeGameIfNeeded() completa
================================================================================

    private func initializeGameIfNeeded() async {
        if currentGame == nil {
            do {
                try await env.gameActor.resetGame()
                
                // Iniciar actividad de Game Center (Continue Playing)
                await MainActor.run {
                    env.activityService.startActivity(type: .mainGame)
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

================================================================================
SNIPPET 2: Reemplazar handleGameStateChange() completa
================================================================================

    private func handleGameStateChange(_ newValue: GameState?) {
        if newValue == .won {
            withAnimation(.easeOut(duration: 0.2)) {
                victorySplash.present()
            }
            triggerVictoryHapticIfNeeded()
            
            // Finalizar actividad con éxito
            env.activityService.endActivity(outcome: .completed)
            
            // Enviar puntuación a leaderboards
            if let game = currentGame {
                Task {
                    await env.leaderboardService.submitScore(attempts: game.attempts.count)
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                victorySplash.dismiss()
            }
            victorySplash.resetHaptic()
        }
        if newValue == .inProgress {
            resetHintUIState()
            
            // Iniciar nueva actividad
            env.activityService.startActivity(type: .mainGame)
        }
    }

================================================================================
SNIPPET 3: Reemplazar startNewGame() completa
================================================================================

    private func startNewGame() {
        // Cerramos la splash antes de resetear para evitar el flash de "ganaste".
        victorySplash.dismiss()
        
        // Finalizar actividad anterior (abandonada)
        env.activityService.endActivity(outcome: .abandoned)
        
        Task(name: "StartNewGame") {
            do {
                try await env.gameActor.resetGame()
                // Limpiar el estado de UI solo después de que el reset sea exitoso
                await MainActor.run {
                    guessText = ""
                    resetHintUIState()
                    
                    // Iniciar nueva actividad
                    env.activityService.startActivity(type: .mainGame)
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    print("❌ Error al resetear juego: \(error)")
                }
            }
        }
    }

================================================================================
FIN DE SNIPPETS
================================================================================

INSTRUCCIONES:

1. Abre GameView.swift
2. Busca cada función (Cmd+F)
3. Selecciona toda la función (desde `private func` hasta el `}` final)
4. Reemplázala con el snippet correspondiente
5. Guarda (Cmd+S)
6. Compila (Cmd+B)

¡Listo!

*/
