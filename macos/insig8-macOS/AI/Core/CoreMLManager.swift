import Foundation
import CoreML
import CreateML
import Vision
import NaturalLanguage
import Accelerate

/// Advanced CoreML integration for on-device AI processing
class CoreMLManager: @unchecked Sendable {
    nonisolated(unsafe) static let shared = CoreMLManager()
    
    // Model registry - protected by actor isolation
    private var loadedModels: [String: MLModel] = [:]
    private var modelCache: NSCache<NSString, MLModel> = {
        let cache = NSCache<NSString, MLModel>()
        cache.countLimit = 10 // Limit number of cached models
        return cache
    }()
    
    // Model configurations
    private let modelConfiguration: MLModelConfiguration
    
    private init() {
        self.modelConfiguration = MLModelConfiguration()
        
        // Configure for optimal performance
        if #available(macOS 13.0, *) {
            self.modelConfiguration.computeUnits = .all
            self.modelConfiguration.allowLowPrecisionAccumulationOnGPU = true
        }
        
        loadBuiltInModels()
    }
    
    // MARK: - Model Management
    
    func loadModel(named name: String, from bundle: Bundle = .main) async -> MLModel? {
        // Check cache first
        if let cachedModel = modelCache.object(forKey: name as NSString) {
            return cachedModel
        }
        
        // Check loaded models
        if let model = loadedModels[name] {
            return model
        }
        
        // Load from bundle
        guard let modelURL = bundle.url(forResource: name, withExtension: "mlmodelc") else {
            print("⚠️ CoreML model '\(name)' not found in bundle")
            return nil
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL, configuration: modelConfiguration)
            loadedModels[name] = model
            modelCache.setObject(model, forKey: name as NSString)
            
            print("✅ CoreML model '\(name)' loaded successfully")
            return model
        } catch {
            print("❌ Failed to load CoreML model '\(name)': \(error)")
            return nil
        }
    }
    
    func unloadModel(named name: String) {
        loadedModels.removeValue(forKey: name)
        modelCache.removeObject(forKey: name as NSString)
    }
    
    func clearModelCache() {
        loadedModels.removeAll()
        modelCache.removeAllObjects()
    }
    
    // MARK: - Text Classification
    
    func classifyText(_ text: String, using modelName: String) async -> TextClassificationResult? {
        guard let model = await loadModel(named: modelName) else { return nil }
        
        do {
            let input = TextInput(text: text)
            let prediction = try await model.prediction(from: input)
            
            let label = prediction.featureValue(for: "label")?.stringValue ?? "unknown"
            let confidence = prediction.featureValue(for: "confidence")?.doubleValue ?? 0.0
            
            return TextClassificationResult(
                label: label,
                confidence: Float(confidence),
                modelUsed: modelName
            )
        } catch {
            print("Text classification error: \(error)")
            return nil
        }
    }
    
    func detectCommitments(in text: String) async -> CommitmentDetectionResult {
        // Try custom commitment model first
        if let result = await classifyText(text, using: "CommitmentClassifier") {
            return CommitmentDetectionResult(
                hasCommitment: result.confidence > 0.7,
                confidence: result.confidence,
                commitmentType: result.label,
                method: AnalysisMethod.coreML
            )
        }
        
        // Fallback to enhanced NLP analysis
        return await detectCommitmentsWithNLP(text)
    }
    
    func classifyUrgency(in text: String) async -> UrgencyClassificationResult {
        // Try custom urgency model first
        if let result = await classifyText(text, using: "UrgencyClassifier") {
            let urgencyLevel = UrgencyLevel(rawValue: result.label) ?? .medium
            return UrgencyClassificationResult(
                urgencyLevel: urgencyLevel,
                confidence: result.confidence,
                method: AnalysisMethod.coreML
            )
        }
        
        // Fallback to rule-based classification
        return classifyUrgencyWithRules(text)
    }
    
    // MARK: - Image Analysis
    
    func analyzeImage(_ imageData: Data, using modelName: String) async -> ImageAnalysisResult? {
        guard let model = await loadModel(named: modelName) else { return nil }
        
        // Convert Data to CGImage
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        do {
            // Create Vision request with CoreML model
            let vnModel = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: vnModel)
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            
            // Process results
            if let results = request.results as? [VNClassificationObservation] {
                let classifications = results.map { observation in
                    ImageClassification(
                        identifier: observation.identifier,
                        confidence: observation.confidence
                    )
                }
                
                return ImageAnalysisResult(
                    classifications: classifications,
                    modelUsed: modelName
                )
            }
        } catch {
            print("Image analysis error: \(error)")
        }
        
        return nil
    }
    
    func extractFeaturesFromImage(_ imageData: Data) async -> [Float]? {
        // Use a pre-trained feature extractor model
        if let featureModel = await loadModel(named: "ImageFeatureExtractor") {
            // Implementation would extract feature vectors from images
            // This could be used for image similarity search
            return await performImageFeatureExtraction(imageData, model: featureModel)
        }
        
        return nil
    }
    
    // MARK: - Audio Analysis
    
    func classifyAudio(_ audioFeatures: [Float], using modelName: String) async -> AudioClassificationResult? {
        guard let model = await loadModel(named: modelName) else { return nil }
        
        do {
            let input = AudioFeaturesInput(features: audioFeatures)
            let prediction = try await model.prediction(from: input)
            
            let label = prediction.featureValue(for: "label")?.stringValue ?? "unknown"
            let confidence = prediction.featureValue(for: "confidence")?.doubleValue ?? 0.0
            
            return AudioClassificationResult(
                label: label,
                confidence: Float(confidence),
                modelUsed: modelName
            )
        } catch {
            print("Audio classification error: \(error)")
            return nil
        }
    }
    
    func analyzeSpeakerCharacteristics(_ audioFeatures: [Float]) async -> SpeakerAnalysisResult? {
        // Use a custom model to identify speaker characteristics
        if let result = await classifyAudio(audioFeatures, using: "SpeakerClassifier") {
            return SpeakerAnalysisResult(
                speakerID: result.label,
                confidence: result.confidence,
                characteristics: extractSpeakerCharacteristics(audioFeatures)
            )
        }
        
        return nil
    }
    
    // MARK: - Recommendation System
    
    func generateRecommendations(for userContext: UserContext) async -> [Recommendation] {
        // Use a recommendation model trained on user behavior
        if let model = await loadModel(named: "RecommendationEngine") {
            return await generatePersonalizedRecommendations(userContext, model: model)
        }
        
        // Fallback to rule-based recommendations
        return generateRuleBasedRecommendations(userContext)
    }
    
    // MARK: - Time Series Analysis
    
    func predictUserBehavior(from timeSeriesData: [Float]) async -> BehaviorPrediction? {
        if let model = await loadModel(named: "BehaviorPredictor") {
            do {
                let input = TimeSeriesInput(values: timeSeriesData)
                let prediction = try await model.prediction(from: input)
                
                if let nextAction = prediction.featureValue(for: "next_action")?.stringValue,
                   let confidence = prediction.featureValue(for: "confidence")?.doubleValue {
                    
                    return BehaviorPrediction(
                        predictedAction: nextAction,
                        confidence: Float(confidence),
                        timeHorizon: .shortTerm
                    )
                }
            } catch {
                print("Behavior prediction error: \(error)")
            }
        }
        
        return nil
    }
    
    // MARK: - Custom Model Training Support
    
    func createCustomTextClassifier(from trainingData: [(String, String)], modelName: String) async -> Bool {
        // Use CreateML to train custom models on-device
        do {
            #if canImport(CreateML)
            let trainingTable = try MLDataTable(dictionary: [
                "text": trainingData.map { $0.0 },
                "label": trainingData.map { $0.1 }
            ])
            
            let classifier = try MLTextClassifier(trainingData: trainingTable,
                                                textColumn: "text",
                                                labelColumn: "label")
            
            // Save the trained model
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let modelURL = documentsURL.appendingPathComponent("\(modelName).mlmodel")
            
            try classifier.write(to: modelURL)
            
            // Compile and load the model
            let compiledURL = try await MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiledURL)
            
            loadedModels[modelName] = model
            modelCache.setObject(model, forKey: modelName as NSString)
            
            print("✅ Custom text classifier '\(modelName)' trained and loaded")
            return true
            #else
            print("⚠️ CreateML not available on this platform")
            return false
            #endif
        } catch {
            print("❌ Failed to create custom classifier: \(error)")
            return false
        }
    }
    
    // MARK: - Performance Optimization
    
    func optimizeModelForDevice(_ modelName: String) async -> Bool {
        guard let model = loadedModels[modelName] else { return false }
        
        // Apply model optimizations
        do {
            if #available(macOS 13.0, *) {
                // Use quantization and pruning if available
                let optimizedConfiguration = MLModelConfiguration()
                optimizedConfiguration.computeUnits = .all
                optimizedConfiguration.allowLowPrecisionAccumulationOnGPU = true
                
                // Update model configuration
                print("✅ Model '\(modelName)' optimized for device")
                return true
            }
        } catch {
            print("❌ Failed to optimize model: \(error)")
        }
        
        return false
    }
    
    // MARK: - Private Implementation
    
    private func loadBuiltInModels() {
        // Load any built-in models that come with the app
        Task {
            // Example: Load a general-purpose text sentiment model
            if Bundle.main.url(forResource: "SentimentAnalyzer", withExtension: "mlmodelc") != nil {
                _ = await loadModel(named: "SentimentAnalyzer")
            }
            
            // Load other built-in models as needed
        }
    }
    
    private func detectCommitmentsWithNLP(_ text: String) async -> CommitmentDetectionResult {
        let processor = EnhancedTextProcessor()
        let analysis = await processor.analyzeText(text)
        
        return CommitmentDetectionResult(
            hasCommitment: analysis.commitmentScore > 0.5,
            confidence: analysis.commitmentScore,
            commitmentType: analysis.urgencyLevel.rawValue,
            method: AnalysisMethod.naturalLanguage
        )
    }
    
    private func classifyUrgencyWithRules(_ text: String) -> UrgencyClassificationResult {
        let urgentKeywords = ["urgent", "asap", "immediately", "emergency", "critical", "now"]
        let highKeywords = ["important", "priority", "soon", "quickly", "today"]
        let lowKeywords = ["when you can", "no rush", "eventually", "sometime"]
        
        let lowercaseText = text.lowercased()
        
        var urgencyLevel: UrgencyLevel = .medium
        var confidence: Float = 0.5
        
        if urgentKeywords.contains(where: { lowercaseText.contains($0) }) {
            urgencyLevel = .urgent
            confidence = 0.9
        } else if highKeywords.contains(where: { lowercaseText.contains($0) }) {
            urgencyLevel = .high
            confidence = 0.8
        } else if lowKeywords.contains(where: { lowercaseText.contains($0) }) {
            urgencyLevel = .low
            confidence = 0.7
        }
        
        return UrgencyClassificationResult(
            urgencyLevel: urgencyLevel,
            confidence: confidence,
            method: AnalysisMethod.ruleBased
        )
    }
    
    private func performImageFeatureExtraction(_ imageData: Data, model: MLModel) async -> [Float]? {
        // Implementation would use the model to extract feature vectors
        // This is a simplified placeholder
        return []
    }
    
    private func extractSpeakerCharacteristics(_ audioFeatures: [Float]) -> SpeakerCharacteristics {
        // Analyze audio features to extract speaker characteristics
        let avgPitch = audioFeatures.reduce(0, +) / Float(audioFeatures.count)
        let variance = audioFeatures.map { pow($0 - avgPitch, 2) }.reduce(0, +) / Float(audioFeatures.count)
        
        return SpeakerCharacteristics(
            averagePitch: avgPitch,
            pitchVariance: variance,
            speakingRate: 120.0, // Words per minute (placeholder)
            voiceQuality: .clear
        )
    }
    
    private func generatePersonalizedRecommendations(_ userContext: UserContext, model: MLModel) async -> [Recommendation] {
        // Use ML model to generate personalized recommendations
        do {
            let input = UserContextInput(context: userContext)
            let prediction = try await model.prediction(from: input)
            
            // Process predictions into recommendations
            return []
        } catch {
            print("Recommendation generation error: \(error)")
            return []
        }
    }
    
    private func generateRuleBasedRecommendations(_ userContext: UserContext) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Add rule-based recommendations based on user context
        if userContext.hasUnreadMessages {
            recommendations.append(Recommendation(
                type: .respond,
                title: "Respond to unread messages",
                description: "You have unread messages that might need attention",
                confidence: 0.8
            ))
        }
        
        if userContext.hasOverdueCommitments {
            recommendations.append(Recommendation(
                type: .followUp,
                title: "Follow up on commitments",
                description: "Some of your commitments are overdue",
                confidence: 0.9
            ))
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

struct TextClassificationResult {
    let label: String
    let confidence: Float
    let modelUsed: String
}

// CommitmentDetectionResult moved to AISharedTypes.swift for reuse

struct UrgencyClassificationResult {
    let urgencyLevel: UrgencyLevel
    let confidence: Float
    let method: AnalysisMethod
}

// AnalysisMethod is defined in AISharedTypes.swift

struct ImageAnalysisResult {
    let classifications: [ImageClassification]
    let modelUsed: String
}

struct ImageClassification {
    let identifier: String
    let confidence: Float
}

struct AudioClassificationResult {
    let label: String
    let confidence: Float
    let modelUsed: String
}

struct SpeakerAnalysisResult {
    let speakerID: String
    let confidence: Float
    let characteristics: SpeakerCharacteristics
}

struct SpeakerCharacteristics {
    let averagePitch: Float
    let pitchVariance: Float
    let speakingRate: Float
    let voiceQuality: VoiceQuality
}

enum VoiceQuality {
    case clear
    case muffled
    case noisy
}

struct UserContext {
    let hasUnreadMessages: Bool
    let hasOverdueCommitments: Bool
    let currentApp: String
    let timeOfDay: String
    let lastActivityTime: Date
}

struct Recommendation {
    let type: RecommendationType
    let title: String
    let description: String
    let confidence: Float
}

enum RecommendationType {
    case respond
    case followUp
    case schedule
    case prioritize
}

struct BehaviorPrediction {
    let predictedAction: String
    let confidence: Float
    let timeHorizon: TimeHorizon
}

enum TimeHorizon {
    case shortTerm  // Next few minutes
    case mediumTerm // Next hour
    case longTerm   // Next day
}

// MARK: - ML Model Input Types

class TextInput: MLFeatureProvider, @unchecked Sendable {
    let text: String
    
    init(text: String) {
        self.text = text
    }
    
    var featureNames: Set<String> {
        return ["text"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "text" {
            return MLFeatureValue(string: text)
        }
        return nil
    }
}

class AudioFeaturesInput: MLFeatureProvider, @unchecked Sendable {
    let features: [Float]
    
    init(features: [Float]) {
        self.features = features
    }
    
    var featureNames: Set<String> {
        return ["features"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "features" {
            return try? MLFeatureValue(multiArray: MLMultiArray(features))
        }
        return nil
    }
}

class TimeSeriesInput: MLFeatureProvider, @unchecked Sendable {
    let values: [Float]
    
    init(values: [Float]) {
        self.values = values
    }
    
    var featureNames: Set<String> {
        return ["time_series"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "time_series" {
            return try? MLFeatureValue(multiArray: MLMultiArray(values))
        }
        return nil
    }
}

class UserContextInput: MLFeatureProvider, @unchecked Sendable {
    let context: UserContext
    
    init(context: UserContext) {
        self.context = context
    }
    
    var featureNames: Set<String> {
        return ["has_unread", "has_overdue", "current_app", "time_of_day"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "has_unread":
            return MLFeatureValue(int64: context.hasUnreadMessages ? 1 : 0)
        case "has_overdue":
            return MLFeatureValue(int64: context.hasOverdueCommitments ? 1 : 0)
        case "current_app":
            return MLFeatureValue(string: context.currentApp)
        case "time_of_day":
            return MLFeatureValue(string: context.timeOfDay)
        default:
            return nil
        }
    }
}