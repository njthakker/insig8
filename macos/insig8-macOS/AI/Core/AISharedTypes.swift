// MARK: - AI Shared Types
// This file provides all AI types with proper compatibility handling

import Foundation

// Always use mock implementations for now to avoid FoundationModels dependency issues
public class AILanguageModelSession {
    public init() {}
    
    public func respond(to prompt: String) async throws -> AIResponse {
        throw AIError.serviceOffline
    }
}

public let isAIAvailable = false

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
// Use real types when available
#else
// Mock types when ScreenCaptureKit not available
public class SCCaptureEngine {
    // Empty mock implementation
}

public class SCCaptureStream {
    // Empty mock implementation  
}

public class SCCaptureScreenshot {
    public let surface: MockSurface = MockSurface()
}

public class MockSurface {
    public let data: Data = Data()
}
#endif

// AI Response and Error types
public struct AIResponse {
    public let content: String
    
    public init(content: String) {
        self.content = content
    }
}

public enum AIError: Error {
    case serviceOffline
    case modelNotAvailable
    case processingFailed
    
    public var localizedDescription: String {
        switch self {
        case .serviceOffline:
            return "On device agent offline"
        case .modelNotAvailable:
            return "AI model not available"
        case .processingFailed:
            return "AI processing failed"
        }
    }
}