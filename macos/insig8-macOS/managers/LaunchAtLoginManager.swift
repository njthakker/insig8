import Foundation
import ServiceManagement

/// Native launch-at-login manager using ServiceManagement framework
/// Replaces third-party LaunchAtLogin package for better compatibility
@available(macOS 13.0, *)
class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private let service = SMAppService.mainApp
    private let bundleId = Bundle.main.bundleIdentifier ?? "com.insig8.macos"
    
    private init() {}
    
    /// Check if launch at login is currently enabled
    var isEnabled: Bool {
        return service.status == .enabled
    }
    
    /// Enable or disable launch at login
    /// - Parameter enabled: Whether to enable launch at login
    /// - Returns: True if the operation was successful
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if service.status == .enabled {
                    return true // Already enabled
                }
                try service.register()
                print("✅ Launch at login enabled successfully")
                return true
            } else {
                if service.status == .notRegistered {
                    return true // Already disabled
                }
                try service.unregister()
                print("✅ Launch at login disabled successfully")
                return true
            }
        } catch {
            print("❌ Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            return false
        }
    }
    
    /// Get current service status
    var status: SMAppService.Status {
        return service.status
    }
    
    /// Get human-readable status description
    var statusDescription: String {
        switch service.status {
        case .notRegistered:
            return "Not registered for launch at login"
        case .enabled:
            return "Launch at login is enabled"
        case .requiresApproval:
            return "Launch at login requires user approval"
        case .notFound:
            return "Service not found"
        @unknown default:
            return "Unknown status"
        }
    }
}

/// Fallback implementation for macOS versions < 13.0
class LaunchAtLoginManagerLegacy {
    static let shared = LaunchAtLoginManagerLegacy()
    
    private let bundleId = Bundle.main.bundleIdentifier ?? "com.insig8.macos"
    private let loginItemsKey = "com.apple.loginitems.plist"
    
    private init() {}
    
    /// Check if launch at login is currently enabled (legacy implementation)
    var isEnabled: Bool {
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)
        guard let loginItemsRef = loginItems?.takeRetainedValue() else {
            return false
        }
        
        let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
        guard let loginItemsArrayRef = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else {
            return false
        }
        
        let bundleURL = Bundle.main.bundleURL
        
        for item in loginItemsArrayRef {
            if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() {
                if itemURL.absoluteString == bundleURL.absoluteString {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Enable or disable launch at login (legacy implementation)
    /// - Parameter enabled: Whether to enable launch at login
    /// - Returns: True if the operation was successful
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)
        guard let loginItemsRef = loginItems?.takeRetainedValue() else {
            print("❌ Failed to access login items")
            return false
        }
        
        let bundleURL = Bundle.main.bundleURL
        
        if enabled {
            // Add to login items
            let result = LSSharedFileListInsertItemURL(
                loginItemsRef,
                kLSSharedFileListItemLast.takeRetainedValue(),
                nil,
                nil,
                bundleURL,
                nil,
                nil
            )
            
            if result != nil {
                print("✅ Launch at login enabled successfully (legacy)")
                return true
            } else {
                print("❌ Failed to enable launch at login (legacy)")
                return false
            }
        } else {
            // Remove from login items
            let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
            guard let loginItemsArrayRef = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else {
                return false
            }
            
            for item in loginItemsArrayRef {
                if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() {
                    if itemURL.absoluteString == bundleURL.absoluteString {
                        let result = LSSharedFileListItemRemove(loginItemsRef, item)
                        if result == noErr {
                            print("✅ Launch at login disabled successfully (legacy)")
                            return true
                        } else {
                            print("❌ Failed to disable launch at login (legacy)")
                            return false
                        }
                    }
                }
            }
            
            // Item not found in login items, consider it already disabled
            return true
        }
    }
}

/// Unified interface that works across macOS versions
class LaunchAtLoginHelper {
    static let shared = LaunchAtLoginHelper()
    
    private init() {}
    
    /// Check if launch at login is currently enabled
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return LaunchAtLoginManager.shared.isEnabled
        } else {
            return LaunchAtLoginManagerLegacy.shared.isEnabled
        }
    }
    
    /// Enable or disable launch at login
    /// - Parameter enabled: Whether to enable launch at login
    /// - Returns: True if the operation was successful
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            return LaunchAtLoginManager.shared.setEnabled(enabled)
        } else {
            return LaunchAtLoginManagerLegacy.shared.setEnabled(enabled)
        }
    }
    
    /// Get status description
    var statusDescription: String {
        if #available(macOS 13.0, *) {
            return LaunchAtLoginManager.shared.statusDescription
        } else {
            return isEnabled ? "Launch at login is enabled (legacy)" : "Launch at login is disabled (legacy)"
        }
    }
}