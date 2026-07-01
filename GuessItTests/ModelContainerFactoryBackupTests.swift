//
//  ModelContainerFactoryBackupTests.swift
//  GuessItTests
//
//  Tests del respaldo NO destructivo del store corrupto (PR 8).
//
//  Se prueba `ModelContainerFactory.backupCorruptStore(at:)` y `storeSidecarURLs(for:)`
//  usando un directorio temporal con archivos "store" y sidecars simulados. No se toca
//  el store real de la app ni se usa SwiftData: son operaciones de FileManager puras.
//

import Testing
import Foundation
@testable import GuessIt

@Suite("ModelContainerFactory - backup no destructivo")
struct ModelContainerFactoryBackupTests {

    // MARK: - Helpers

    /// Crea un directorio temporal único y devuelve su URL.
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GuessItBackupTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Escribe un archivo con contenido dummy en la URL dada.
    private func writeDummy(_ url: URL, _ content: String = "dummy") throws {
        try content.data(using: .utf8)!.write(to: url)
    }

    /// Lista los backups (`*.corrupt-*.bak`) presentes en un directorio.
    private func backupFiles(in dir: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.contains(".corrupt-") && $0.hasSuffix(".bak") }
    }

    // MARK: - storeSidecarURLs

    @Test("Los sidecars se derivan como <archivo>-wal y <archivo>-shm (no reemplazando extensión)")
    func sidecarNamesAreCorrect() {
        let store = URL(fileURLWithPath: "/tmp/whatever/default.store")
        let names = ModelContainerFactory.storeSidecarURLs(for: store).map { $0.lastPathComponent }
        #expect(names.contains("default.store-wal"), "El sidecar WAL debe conservar el nombre completo del store")
        #expect(names.contains("default.store-shm"), "El sidecar SHM debe conservar el nombre completo del store")
    }

    // MARK: - backupCorruptStore

    @Test("Respalda el archivo principal y ambos sidecars cuando existen")
    func backsUpMainAndSidecars() throws {
        let dir = try makeTempDir()
        let store = dir.appendingPathComponent("default.store")
        try writeDummy(store, "main")
        // Sidecars WAL/SHM con el nombre completo del store.
        try writeDummy(dir.appendingPathComponent("default.store-wal"), "wal")
        try writeDummy(dir.appendingPathComponent("default.store-shm"), "shm")

        let backup = try ModelContainerFactory.backupCorruptStore(at: store)

        #expect(backup != nil, "Debe devolver la URL del backup del archivo principal")
        let backups = try backupFiles(in: dir)
        // main + 2 sidecars = 3 backups.
        #expect(backups.count == 3, "Deben respaldarse el archivo principal y sus dos sidecars")
        #expect(backups.contains { $0.hasPrefix("default.store.corrupt-") })
        #expect(backups.contains { $0.hasPrefix("default.store-wal.corrupt-") })
        #expect(backups.contains { $0.hasPrefix("default.store-shm.corrupt-") })
        // El original NO se borra: el backup es una copia.
        #expect(FileManager.default.fileExists(atPath: store.path), "El backup no debe borrar el original")
    }

    @Test("No falla si faltan los sidecars (solo respalda el archivo principal)")
    func doesNotFailWhenSidecarsMissing() throws {
        let dir = try makeTempDir()
        let store = dir.appendingPathComponent("default.store")
        try writeDummy(store, "main")
        // Sin sidecars a propósito.

        let backup = try ModelContainerFactory.backupCorruptStore(at: store)

        #expect(backup != nil)
        let backups = try backupFiles(in: dir)
        #expect(backups.count == 1, "Solo debe existir el backup del archivo principal")
        #expect(backups.first?.hasPrefix("default.store.corrupt-") == true)
    }

    @Test("Devuelve nil cuando no existe el archivo principal (nada que respaldar)")
    func returnsNilWhenNoMainFile() throws {
        let dir = try makeTempDir()
        let store = dir.appendingPathComponent("default.store") // no se crea

        let backup = try ModelContainerFactory.backupCorruptStore(at: store)

        #expect(backup == nil, "Sin archivo principal no hay backup útil")
        #expect(try backupFiles(in: dir).isEmpty, "No debe crearse ningún backup")
    }
}
