# ✅ Checklist de Implementación - Game Center iOS 26

## 📋 Fase 1: Código (5 minutos)

### GameView.swift - Integración Manual

- [ ] Abrir `GameView.swift`
- [ ] Abrir `GameView_IntegrationSnippets.swift` (referencia)
- [ ] Buscar `initializeGameIfNeeded()` (Cmd+F)
- [ ] Reemplazar función completa con SNIPPET 1
- [ ] Buscar `handleGameStateChange()` (Cmd+F)
- [ ] Reemplazar función completa con SNIPPET 2
- [ ] Buscar `startNewGame()` (Cmd+F)
- [ ] Reemplazar función completa con SNIPPET 3
- [ ] Guardar (Cmd+S)
- [ ] Compilar (Cmd+B)
- [ ] ✅ **Verificar que compila sin errores**

---

## 🏗️ Fase 2: App Store Connect (30 minutos)

### Leaderboards

- [ ] Ir a App Store Connect → Tu App → Game Center → Leaderboards
- [ ] Click "Add Leaderboard"

#### Leaderboard 1: All-Time Best
- [ ] ID: `com.antolini.GuessIt.leaderboard.alltime`
- [ ] Name: "Best Score"
- [ ] Type: **Classic**
- [ ] Sort: **High to Low**
- [ ] Score Format: **Integer**
- [ ] Score Range: 1-99
- [ ] Challenge Enabled: **No**
- [ ] Submit to Review

#### Leaderboard 2: Weekly Challenge
- [ ] ID: `com.antolini.GuessIt.leaderboard.weekly`
- [ ] Name: "Weekly Challenge"
- [ ] Type: **Recurring**
- [ ] Reset: **Weekly (Monday 00:00 UTC)**
- [ ] Sort: **High to Low**
- [ ] Score Format: **Integer**
- [ ] Score Range: 1-99
- [ ] Challenge Enabled: **Yes**
- [ ] Submit to Review

#### Leaderboard 3: Daily Challenge
- [ ] ID: `com.antolini.GuessIt.leaderboard.daily`
- [ ] Name: "Daily Challenge"
- [ ] Type: **Recurring**
- [ ] Reset: **Daily (00:00 UTC)**
- [ ] Sort: **High to Low**
- [ ] Score Format: **Integer**
- [ ] Score Range: 1-99
- [ ] Challenge Enabled: **Yes**
- [ ] Submit to Review

---

### Activities

- [ ] Ir a App Store Connect → Tu App → Game Center → Activities
- [ ] Click "Add Activity"

#### Activity 1: Main Game
- [ ] ID: `com.antolini.GuessIt.activity.main_game`
- [ ] Name: "Playing GuessIt"
- [ ] Type: **Gameplay**
- [ ] Deep Link: `guessit://game/main`
- [ ] Localizations:
  - [ ] 🇪🇸 Spanish: "Jugando GuessIt"
  - [ ] 🇺🇸 English: "Playing GuessIt"
- [ ] Submit to Review

#### Activity 2: Daily Challenge
- [ ] ID: `com.antolini.GuessIt.activity.daily_challenge`
- [ ] Name: "Daily Challenge"
- [ ] Type: **Gameplay**
- [ ] Deep Link: `guessit://game/daily`
- [ ] Localizations:
  - [ ] 🇪🇸 Spanish: "Desafío Diario"
  - [ ] 🇺🇸 English: "Daily Challenge"
- [ ] Submit to Review

---

## 🔐 Fase 3: Entitlements (5 minutos)

### Info.plist

- [ ] Abrir proyecto en Xcode
- [ ] Seleccionar target "GuessIt"
- [ ] Tab "Signing & Capabilities"
- [ ] Click "+" → "Game Center"
- [ ] Abrir `Info.plist` como Source Code (Right Click → Open As → Source Code)
- [ ] Agregar este XML:

```xml
<key>com.apple.developer.game-center.activities</key>
<array>
    <string>com.antolini.GuessIt.activity.main_game</string>
    <string>com.antolini.GuessIt.activity.daily_challenge</string>
</array>
```

- [ ] Guardar
- [ ] ✅ **Verificar que compila**

---

## 🎨 Fase 4: Assets (1-2 horas)

### App Icon - Layered

- [ ] Abrir Assets.xcassets
- [ ] Seleccionar "AppIcon"
- [ ] Right Click → "New iOS App Icon (Layered)"
- [ ] Preparar 3 imágenes (1024x1024):
  - [ ] **Base.png** - Fondo sólido
  - [ ] **Layer1.png** - Capa intermedia (transparente)
  - [ ] **Layer2.png** - Capa frontal (transparente)
- [ ] Specs:
  - [ ] Color Space: Display P3
  - [ ] Formato: PNG
  - [ ] Separación visual: 10-20px entre capas
- [ ] Arrastrar archivos a los slots correspondientes
- [ ] ✅ **Verificar preview con efecto paralaje**

---

### Activity Images (16:9)

- [ ] Crear nuevo Image Set: "main_game_activity"
- [ ] Preparar imágenes:
  - [ ] main_game@2x.png (1920x1080)
  - [ ] main_game@3x.png (2880x1620)
- [ ] Specs:
  - [ ] Ratio: **Exactamente 16:9**
  - [ ] **No incluir texto** (el sistema lo superpone)
  - [ ] Mostrar gameplay representativo
  - [ ] Color Space: Display P3
- [ ] Arrastrar a los slots @2x y @3x
- [ ] Repetir para "daily_challenge_activity"
  - [ ] daily_challenge@2x.png (1920x1080)
  - [ ] daily_challenge@3x.png (2880x1620)
- [ ] ✅ **Verificar que las imágenes se ven bien en Preview**

---

## 🧪 Fase 5: Testing (30 minutos)

### Xcode - Game Progress Manager

- [ ] Abrir Xcode 26.3+
- [ ] Menu: **Product → Game Progress Manager**
- [ ] Verificar pestañas:
  - [ ] Activities
  - [ ] Leaderboards
  - [ ] Achievements

#### Test 1: Activity Started
- [ ] Click "Simulate Activity Started"
- [ ] Activity ID: `com.antolini.GuessIt.activity.main_game`
- [ ] ✅ **Verificar que aparece en la lista**

#### Test 2: Score Submission
- [ ] Click "Simulate Score Submission"
- [ ] Leaderboard: `com.antolini.GuessIt.leaderboard.weekly`
- [ ] Score: 95
- [ ] ✅ **Verificar que aparece en leaderboard**

#### Test 3: Deep Link
- [ ] Click "Simulate Deep Link"
- [ ] Activity: `com.antolini.GuessIt.activity.main_game`
- [ ] ✅ **Verificar que la app navega correctamente**

---

### Simulador iOS 26

- [ ] Ejecutar app en Simulador iOS 26
- [ ] Autenticarse con Apple ID de prueba
- [ ] Verificaciones iniciales:
  - [ ] ✅ GKAccessPoint badge visible en esquina superior izquierda
  - [ ] ✅ Badge tiene efecto Liquid Glass (transparente)
  - [ ] ✅ Al tocar badge, abre menu de Game Center

#### Test 4: Jugar una Partida
- [ ] Iniciar nueva partida
- [ ] Hacer varios intentos
- [ ] Ganar la partida
- [ ] Verificar:
  - [ ] ✅ Banner de victoria se muestra
  - [ ] ✅ Haptic feedback se dispara
  - [ ] ✅ No hay errores en console

#### Test 5: Apple Games App
- [ ] Salir de GuessIt (Home button)
- [ ] Abrir app "Apple Games" en simulador
- [ ] Tab "Home":
  - [ ] ✅ "Continue Playing" muestra GuessIt
  - [ ] ✅ Image de actividad se muestra correctamente
  - [ ] ✅ Al tocar, abre GuessIt
- [ ] Tab "Friends":
  - [ ] ✅ Activity feed muestra "Jugando GuessIt"
- [ ] Tab "Leaderboards":
  - [ ] ✅ "Weekly Challenge" muestra puntuación
  - [ ] ✅ Botón "Challenge" habilitado

---

### Dispositivo Real (Opcional pero Recomendado)

- [ ] Instalar via TestFlight
- [ ] Autenticarse con tu Apple ID real
- [ ] Repetir Test 4 y Test 5
- [ ] Verificaciones adicionales:
  - [ ] ✅ Liquid Glass se ve mejor que en simulador
  - [ ] ✅ Badge tiene reflejo de luz ambiente
  - [ ] ✅ Iconos con capas tienen efecto paralaje

---

## 📊 Fase 6: Métricas (Post-lanzamiento)

### App Store Connect Analytics

Después de 7 días con usuarios reales:

- [ ] Ir a App Store Connect → Analytics → Game Center
- [ ] Verificar:
  - [ ] **Sessions from Continue Playing** > 0%
  - [ ] **Leaderboard Submissions** > 0
  - [ ] **Challenges Sent** > 0
  - [ ] **Active Activities** trending up

### Metas de Éxito

- [ ] 📈 Retención D7 incrementó +10% o más
- [ ] 📈 25%+ de sesiones vienen de "Continue Playing"
- [ ] 📈 Leaderboard submission rate > 50%
- [ ] 📈 Challenge acceptance rate > 30%

---

## 🐛 Troubleshooting Checklist

### Problema: GKAccessPoint no aparece

- [ ] Verificar que `GKAccessPoint.shared.isActive = true`
- [ ] Verificar que usuario está autenticado
- [ ] Check console para errores de GameKit
- [ ] Reiniciar app completamente

### Problema: Activities no aparecen en Apple Games

- [ ] Verificar activity IDs coinciden (código ↔ App Store Connect)
- [ ] Verificar entitlements en Info.plist
- [ ] Verificar que `activity.start()` se llamó sin errores
- [ ] Reinstalar app desde TestFlight (no debug)
- [ ] Wait 5-10 minutos (propagación de servidores)

### Problema: Leaderboards no aceptan puntuaciones

- [ ] Verificar leaderboard está "Ready for Sale"
- [ ] Verificar leaderboard IDs coinciden
- [ ] Check logs: buscar "Failed to submit score"
- [ ] Verificar usuario autenticado
- [ ] Verificar score está en rango válido (1-99)

### Problema: Deep Links no funcionan

- [ ] Verificar `activity.handled = true` en listener
- [ ] Verificar deep link URL en App Store Connect
- [ ] Check que `GKLocalPlayerListener` está registrado
- [ ] Verificar navegación en `player(_:wantsToPlay:)`

---

## ✨ Checklist Final

- [ ] ✅ Código compilando sin warnings
- [ ] ✅ 3 leaderboards configurados en App Store Connect
- [ ] ✅ 2 activities configuradas en App Store Connect
- [ ] ✅ Entitlements agregados a Info.plist
- [ ] ✅ App Icon con capas (Liquid Glass)
- [ ] ✅ Activity images 16:9 (Display P3)
- [ ] ✅ Testing en Game Progress Manager exitoso
- [ ] ✅ Testing en Simulador iOS 26 exitoso
- [ ] ✅ Testing en dispositivo real exitoso
- [ ] ✅ GKAccessPoint visible y funcional
- [ ] ✅ Continue Playing muestra actividad
- [ ] ✅ Leaderboards aceptan puntuaciones
- [ ] ✅ Deep links funcionan correctamente

---

## 🚀 Listo para Lanzar

**Cuando todos los checkmarks estén ✅:**

1. Commit y push cambios
2. Crear build de Release
3. Subir a TestFlight
4. Distribuir a testers beta
5. Monitorear métricas por 7 días
6. Analizar impacto en retención
7. Submit to App Store Review

**Tiempo total estimado:** 3-4 horas

**Impacto esperado:**
- 📈 Retención D7: +30-50%
- 📈 Engagement: +40-60%
- 📈 Viralidad: +50% (con amigos activos)

---

## 📞 Soporte

Si encuentras problemas no listados aquí:

1. Check logs en Xcode Console
2. Review documentación oficial: [Apple Games app](https://developer.apple.com/games-app/)
3. Apple Developer Forums: [Game Center](https://developer.apple.com/forums/topics/game-center)
4. File radar si encuentras bug en iOS 26

---

¡Éxito con la implementación! 🎉
