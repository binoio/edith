//
//  DocumentRestoreManager.swift
//  Edith
//
//  Manages saving and restoring document state for crash recovery and session restore.
//

import Foundation
import AppKit

class DocumentRestoreManager {
    static let shared = DocumentRestoreManager()
    
    private let restoreDirectory: URL
    private let openDocumentsFile: URL
    private let fileManager = FileManager.default
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        restoreDirectory = appSupport.appendingPathComponent("Edith/Restore", isDirectory: true)
        openDocumentsFile = restoreDirectory.appendingPathComponent("open_documents.json")
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Open Documents Tracking
    
    struct OpenDocumentInfo: Codable {
        let path: String
        let hasUnsavedChanges: Bool
        let restoreID: String
        /// Security-scoped bookmark so the sandboxed app can reopen the file
        /// on the next launch without a new open panel.
        let bookmark: Data?
        /// Untitled documents have no path; their content lives in a backup
        /// keyed by restoreID.
        let isUntitled: Bool
        
        init(path: String, hasUnsavedChanges: Bool, restoreID: String,
             bookmark: Data? = nil, isUntitled: Bool = false) {
            self.path = path
            self.hasUnsavedChanges = hasUnsavedChanges
            self.restoreID = restoreID
            self.bookmark = bookmark
            self.isUntitled = isUntitled
        }
        
        init(from decoder: Decoder) throws {
            // Sessions written before bookmarks/untitled support lack the
            // newer keys; default them so old sessions still restore.
            let container = try decoder.container(keyedBy: CodingKeys.self)
            path = try container.decode(String.self, forKey: .path)
            hasUnsavedChanges = try container.decode(Bool.self, forKey: .hasUnsavedChanges)
            restoreID = try container.decode(String.self, forKey: .restoreID)
            bookmark = try container.decodeIfPresent(Data.self, forKey: .bookmark)
            isUntitled = try container.decodeIfPresent(Bool.self, forKey: .isUntitled) ?? false
        }
    }
    
    func saveOpenDocuments(_ documents: [OpenDocumentInfo]) {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: openDocumentsFile)
        } catch {
            print("Failed to save open documents: \(error)")
        }
    }
    
    func loadOpenDocuments() -> [OpenDocumentInfo] {
        guard fileManager.fileExists(atPath: openDocumentsFile.path) else { return [] }
        do {
            let data = try Data(contentsOf: openDocumentsFile)
            return try JSONDecoder().decode([OpenDocumentInfo].self, from: data)
        } catch {
            print("Failed to load open documents: \(error)")
            return []
        }
    }
    
    func clearOpenDocuments() {
        try? fileManager.removeItem(at: openDocumentsFile)
    }
    
    // MARK: - Unsaved Content Backup
    
    func saveUnsavedContent(_ content: String, restoreID: String) {
        let backupFile = restoreDirectory.appendingPathComponent("\(restoreID).backup")
        do {
            try content.write(to: backupFile, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save backup for \(restoreID): \(error)")
        }
    }
    
    func loadUnsavedContent(restoreID: String) -> String? {
        let backupFile = restoreDirectory.appendingPathComponent("\(restoreID).backup")
        guard fileManager.fileExists(atPath: backupFile.path) else { return nil }
        return try? String(contentsOf: backupFile, encoding: .utf8)
    }
    
    func clearUnsavedContent(restoreID: String) {
        let backupFile = restoreDirectory.appendingPathComponent("\(restoreID).backup")
        try? fileManager.removeItem(at: backupFile)
    }
    
    func clearAllBackups() {
        let contents = (try? fileManager.contentsOfDirectory(at: restoreDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in contents where file.pathExtension == "backup" {
            try? fileManager.removeItem(at: file)
        }
    }
    
    // MARK: - Auto-save Timer
    
    private var autoSaveTimer: Timer?
    private var pendingBackups: [String: String] = [:]
    
    func scheduleBackup(restoreID: String, content: String) {
        pendingBackups[restoreID] = content
        
        // Debounce: save after 2 seconds of inactivity
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.flushPendingBackups()
        }
    }
    
    func flushPendingBackups() {
        for (restoreID, content) in pendingBackups {
            saveUnsavedContent(content, restoreID: restoreID)
        }
        pendingBackups.removeAll()
    }
}

// MARK: - File Change Monitor

class FileChangeMonitor {
    private var monitoredFiles: [String: (source: DispatchSourceFileSystemObject, lastModified: Date)] = [:]
    var onFileChanged: ((String) -> Void)?
    
    func startMonitoring(path: String) {
        guard monitoredFiles[path] == nil else { return }
        
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        
        let lastModified = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date()
        
        source.setEventHandler { [weak self] in
            self?.handleFileChange(path: path)
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        monitoredFiles[path] = (source, lastModified)
    }
    
    func stopMonitoring(path: String) {
        if let entry = monitoredFiles.removeValue(forKey: path) {
            entry.source.cancel()
        }
    }
    
    func stopAll() {
        for (_, entry) in monitoredFiles {
            entry.source.cancel()
        }
        monitoredFiles.removeAll()
    }
    
    private func handleFileChange(path: String) {
        guard let entry = monitoredFiles[path] else { return }
        
        // Check if modification date actually changed
        if let newDate = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date,
           newDate > entry.lastModified {
            monitoredFiles[path] = (entry.source, newDate)
            onFileChanged?(path)
        }
    }
}

// MARK: - Live Session Tracking

/// A live document window's contribution to the saved session. ContentView
/// fills in the closures; the coordinator pulls current state through them
/// whenever it snapshots the session.
final class DocumentSessionHandle {
    let id = UUID()
    var resolveDocument: () -> NSDocument? = { nil }
    var currentText: () -> String = { "" }
    
    var restoreID: String { id.uuidString }
}

/// Continuously snapshots the set of open documents — with security-scoped
/// bookmarks and unsaved-content backups — so quitting the app (or crashing)
/// can be resumed exactly where the user left off.
final class DocumentSessionCoordinator {
    static let shared = DocumentSessionCoordinator()
    
    private var handles: [DocumentSessionHandle] = []
    private var persistTimer: Timer?
    private var isTerminating = false
    /// Tests persist explicitly; the debounced automatic persistence of the
    /// hosting app would otherwise race them for the session file.
    var automaticPersistenceSuspended = false
    
    private var reopenDocumentsOnLaunch: Bool {
        UserDefaults.standard.object(forKey: "reopenDocumentsOnLaunch") == nil
            ? true : UserDefaults.standard.bool(forKey: "reopenDocumentsOnLaunch")
    }
    
    private var restoreUnsavedChanges: Bool {
        UserDefaults.standard.object(forKey: "restoreUnsavedChanges") == nil
            ? true : UserDefaults.standard.bool(forKey: "restoreUnsavedChanges")
    }
    
    func register(_ handle: DocumentSessionHandle) {
        guard !handles.contains(where: { $0 === handle }) else { return }
        handles.append(handle)
        schedulePersist()
    }
    
    func unregister(_ handle: DocumentSessionHandle) {
        handles.removeAll { $0 === handle }
        schedulePersist()
    }
    
    func noteChange() {
        schedulePersist()
    }
    
    /// Snapshot the session while every window is still open, then stop
    /// persisting: the window teardown that follows must not overwrite the
    /// snapshot with a shrinking session.
    func beginTermination() {
        persistNow()
        isTerminating = true
        persistTimer?.invalidate()
    }
    
    private func schedulePersist() {
        guard !isTerminating, !automaticPersistenceSuspended else { return }
        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.persistNow()
        }
    }
    
    func persistNow() {
        guard !isTerminating else { return }
        let manager = DocumentRestoreManager.shared
        guard reopenDocumentsOnLaunch else {
            manager.clearOpenDocuments()
            manager.clearAllBackups()
            return
        }
        
        var infos: [DocumentRestoreManager.OpenDocumentInfo] = []
        var backups: [String: String] = [:]
        
        for handle in handles {
            let document = handle.resolveDocument()
            let text = handle.currentText()
            if let url = document?.fileURL {
                let isDirty = document?.isDocumentEdited ?? false
                let bookmark = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil)
                infos.append(.init(
                    path: url.path,
                    hasUnsavedChanges: isDirty,
                    restoreID: handle.restoreID,
                    bookmark: bookmark))
                if isDirty && restoreUnsavedChanges {
                    backups[handle.restoreID] = text
                }
            } else {
                // Untitled: only worth restoring if it has content
                guard restoreUnsavedChanges, !text.isEmpty else { continue }
                infos.append(.init(
                    path: "",
                    hasUnsavedChanges: true,
                    restoreID: handle.restoreID,
                    isUntitled: true))
                backups[handle.restoreID] = text
            }
        }
        
        manager.saveOpenDocuments(infos)
        manager.clearAllBackups()
        for (restoreID, content) in backups {
            manager.saveUnsavedContent(content, restoreID: restoreID)
        }
    }
}

/// Content stashed during launch for restored windows to claim as they appear.
final class PendingSessionRestore {
    static let shared = PendingSessionRestore()
    /// Unsaved changes for reopened files, keyed by file path.
    var contentByPath: [String: String] = [:]
    /// Contents of restored untitled documents, claimed in order.
    var untitledContents: [String] = []
    private init() {}
}
