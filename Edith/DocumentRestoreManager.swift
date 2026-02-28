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
