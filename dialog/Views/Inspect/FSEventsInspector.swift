//
//  FSEventsInspector.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//  FSEvents monitoring system
//

import Foundation

/// Protocol for FSEvents monitoring delegate callbacks
/// Extends the existing FileSystemMonitorProtocol from AppInspector

protocol FSEventsInspectorDelegate: AnyObject {
    func appInstalled(_ appId: String, at path: String)
    func appUninstalled(_ appId: String, at path: String)
    func cacheFileCreated(_ path: String)
    func cacheFileRemoved(_ path: String)
}

class FSEventsInspector {
    
    // MARK: - Properties
    weak var delegate: FSEventsInspectorDelegate?
    
    private var fsEventStream: FSEventStreamRef?
    private var monitoredApps: [InspectConfig.ItemConfig] = []
    private var cachePaths: [String] = []
    private var eventDebouncer = EventDebouncer()
    private var pathToAppMap: [String: String] = [:] // path -> appId mapping for O(1) lookup
    
    // MARK: - Public Interface
    
    func startMonitoring(apps: [InspectConfig.ItemConfig], cachePaths: [String]) {
        self.monitoredApps = apps
        self.cachePaths = cachePaths
        
        buildCachePathMappings()
        setupCacheFSEvents()
        
        writeLog("FSEventsInspector: Started cache-only monitoring for \(cachePaths.count) cache paths", logLevel: .info)
    }
    
    func stopMonitoring() {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
            
            eventDebouncer.cleanupDebouncer()
            
            writeLog("FSEventsInspector: Stopped monitoring and cleaned up resources", logLevel: .info)
        }
    }
    
    // MARK: - Private Implementation
    
    private func buildCachePathMappings() {
        pathToAppMap.removeAll()
                
        writeLog("FSEventsInspector: Cache-only monitoring - no path mappings needed", logLevel: .debug)
    }
    
    private func setupCacheFSEvents() {
        var pathsToWatch = Set<String>()
        
            for cachePath in cachePaths {
            if FileManager.default.fileExists(atPath: cachePath) {
                pathsToWatch.insert(cachePath)
            }
        }
        
        let pathsArray = Array(pathsToWatch)
        guard !pathsArray.isEmpty else {
            writeLog("FSEventsInspector: No cache paths to monitor", logLevel: .info)
            return
        }
        
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
            retain: nil,
            release: { info in
                if let info = info {
                    Unmanaged<FSEventsInspector>.fromOpaque(info).release()
                }
            },
            copyDescription: nil
        )
        
        let callback: FSEventStreamCallback = { _, clientInfo, numEvents, eventPaths, eventFlags, eventIds in
            guard let clientInfo = clientInfo else { return }
            let monitor = Unmanaged<FSEventsInspector>.fromOpaque(clientInfo).takeUnretainedValue()
            
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            
            for i in 0..<numEvents {
                let path = paths[i]
                let flags = eventFlags[i]
                
                guard monitor.isMonitoredPath(path) else { continue }
                
                monitor.eventDebouncer.debounce(key: path, delay: 0.1) {
                    monitor.handleOptimizedFSEvent(path: path, flags: flags)
                }
                
                if i % 1000 == 0 {
                    monitor.eventDebouncer.cleanupDebouncer()
                }
            }
        }
        
        fsEventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsArray as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1, 
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )
        
        guard let stream = fsEventStream else {
            writeLog("FSEventsInspector: Failed to create FSEventStream", logLevel: .error)
            return
        }
        
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        
        writeLog("FSEventsInspector: Started FSEvents monitoring \(pathsArray.count) paths", logLevel: .info)
    }
    
    private func isMonitoredPath(_ path: String) -> Bool {
        for cachePath in cachePaths {
            if path.hasPrefix(cachePath) {
                return true
            }
        }
        
        return false
    }
    
    private func handleOptimizedFSEvent(path: String, flags: FSEventStreamEventFlags) {
        DispatchQueue.main.async { [weak self] in
            self?.processEvent(path: path, flags: flags)
        }
    }
    
    private func processEvent(path: String, flags: FSEventStreamEventFlags) {
        let isCreated = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
        let isRemoved = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0
        
        if isCreated {
            handleFileCreated(at: path)
        } else if isRemoved {
            handleFileRemoved(at: path)
        }
    }
    
    private func handleFileCreated(at path: String) {
        if isCacheFile(path) {
            delegate?.cacheFileCreated(path)
            writeLog("FSEventsInspector: Detected cache file creation - \(path)", logLevel: .debug)
        }
    }
    
    private func handleFileRemoved(at path: String) {       
        if isCacheFile(path) {
            delegate?.cacheFileRemoved(path)
            writeLog("FSEventsInspector: Detected cache file removal - \(path)", logLevel: .debug)
        }
    }
    
    private func findAppIdForPath(_ path: String) -> String? {
        if let appId = pathToAppMap[path] {
            return appId
        }
        
        for (monitoredPath, appId) in pathToAppMap {
            if path.hasPrefix(monitoredPath) {
                return appId
            }
        }
        
        return nil
    }
    
    private func isCacheFile(_ path: String) -> Bool {
        let lowercasePath = path.lowercased()
        return lowercasePath.hasSuffix(".pkg") || 
               lowercasePath.hasSuffix(".dmg") || 
               lowercasePath.hasSuffix(".download")
    }
}

// MARK: - Event Debouncer

/// This should debounce potential rapid FSEvents to prevent excessive UI updates
private class EventDebouncer {
    private var pendingEvents: [String: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "fs.events.debouncer", qos: .userInitiated)
    
    func debounce(key: String, delay: TimeInterval, action: @escaping () -> Void) {

        pendingEvents[key]?.cancel()
        
        let workItem = DispatchWorkItem {
            action()
            DispatchQueue.main.async {
                self.pendingEvents.removeValue(forKey: key)
            }
        }
        
        pendingEvents[key] = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    func cleanupDebouncer() {
        for workItem in pendingEvents.values {
            workItem.cancel()
        }
        pendingEvents.removeAll()
    }
}
