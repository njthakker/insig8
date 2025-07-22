import Foundation
import NaturalLanguage
import CreateML
import CoreML

/// Enhanced text processing using native NaturalLanguage framework with advanced features
class EnhancedTextProcessor {
    private let languageRecognizer: NLLanguageRecognizer
    private let sentimentPredictor: NLModel?
    private let tokenizer: NLTokenizer
    private let tagger: NLTagger
    
    // Custom ML models for domain-specific tasks
    private var commitmentClassifier: MLModel?
    private var urgencyClassifier: MLModel?
    
    init() {
        self.languageRecognizer = NLLanguageRecognizer()
        self.tokenizer = NLTokenizer(unit: .word)
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .language, .script])
        
        // Initialize sentiment analysis - using fallback since SentimentClassifier is not available
        self.sentimentPredictor = nil
        
        // Load custom models if available
        loadCustomModels()
    }
    
    // MARK: - Advanced Text Analysis
    
    func analyzeText(_ text: String) async -> TextAnalysisResult {
        var result = TextAnalysisResult(text: text)
        
        // Basic language detection
        languageRecognizer.processString(text)
        result.language = languageRecognizer.dominantLanguage ?? .undetermined
        result.languageConfidence = languageRecognizer.languageHypotheses(withMaximum: 5)
        
        // Sentiment analysis
        result.sentiment = await analyzeSentiment(text)
        
        // Named entity recognition
        result.namedEntities = extractNamedEntities(from: text)
        
        // Linguistic analysis
        result.linguisticTags = performLinguisticAnalysis(text)
        
        // Commitment detection using custom model
        result.commitmentScore = await detectCommitment(in: text)
        
        // Urgency classification
        result.urgencyLevel = await classifyUrgency(text)
        
        // Extract key phrases
        result.keyPhrases = extractKeyPhrases(from: text)
        
        return result
    }
    
    func analyzeSentiment(_ text: String) async -> SentimentAnalysis {
        guard let sentimentPredictor = sentimentPredictor else {
            // Fallback to rule-based sentiment analysis
            return performRuleBasedSentiment(text)
        }
        
        do {
            guard let predictor = sentimentPredictor else {
                // Fallback to rule-based sentiment analysis
                return performRuleBasedSentiment(text)
            }
            let prediction = try predictor.prediction(from: text)
            
            if let label = prediction.label {
                let confidence = prediction.confidence
                return SentimentAnalysis(
                    polarity: mapSentimentLabel(label),
                    confidence: Float(confidence),
                    method: .coreML
                )
            }
        } catch {
            print("Sentiment analysis error: \(error)")
        }
        
        return performRuleBasedSentiment(text)
    }
    
    func extractNamedEntities(from text: String) -> [NamedEntity] {
        tagger.string = text
        var entities: [NamedEntity] = []
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                           unit: .word,
                           scheme: .nameType,
                           options: options) { tag, range in
            
            if let tag = tag {
                let entity = String(text[range])
                let entityType = mapNameTypeTag(tag)
                
                entities.append(NamedEntity(
                    text: entity,
                    type: entityType,
                    range: range,
                    confidence: 1.0 // NLTagger doesn't provide confidence scores
                ))
            }
            
            return true
        }
        
        return entities
    }
    
    func performLinguisticAnalysis(_ text: String) -> LinguisticAnalysis {
        tagger.string = text
        var analysis = LinguisticAnalysis()
        
        // Tokenization
        tokenizer.string = text
        analysis.wordCount = tokenizer.tokens(for: text.startIndex..<text.endIndex).count
        analysis.sentences = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        // Part of speech tagging
        var partsOfSpeech: [String: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                           unit: .word,
                           scheme: .lexicalClass,
                           options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            
            if let tag = tag {
                let key = tag.rawValue
                partsOfSpeech[key, default: 0] += 1
            }
            
            return true
        }
        
        analysis.partsOfSpeech = partsOfSpeech
        
        // Language characteristics
        analysis.languageCharacteristics = analyzeLanguageCharacteristics(text)
        
        return analysis
    }
    
    func extractKeyPhrases(from text: String) -> [KeyPhrase] {
        var keyPhrases: [KeyPhrase] = []
        
        // Use part-of-speech patterns to identify noun phrases and important terms
        tagger.string = text
        var currentPhrase: [String] = []
        var phraseRange: Range<String.Index>?
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                           unit: .word,
                           scheme: .lexicalClass,
                           options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            
            let word = String(text[range])
            
            // Build noun phrases (simplified pattern)
            if let tag = tag {
                switch tag {
                case .noun, .adjective:
                    currentPhrase.append(word)
                    if phraseRange == nil {
                        phraseRange = range
                    } else {
                        phraseRange = phraseRange!.lowerBound..<range.upperBound
                    }
                default:
                    if !currentPhrase.isEmpty && currentPhrase.count >= 2 {
                        let phrase = currentPhrase.joined(separator: " ")
                        keyPhrases.append(KeyPhrase(
                            text: phrase,
                            importance: calculatePhraseImportance(phrase),
                            range: phraseRange!
                        ))
                    }
                    currentPhrase = []
                    phraseRange = nil
                }
            }
            
            return true
        }
        
        // Handle final phrase
        if !currentPhrase.isEmpty && currentPhrase.count >= 2 {
            let phrase = currentPhrase.joined(separator: " ")
            if let range = phraseRange {
                keyPhrases.append(KeyPhrase(
                    text: phrase,
                    importance: calculatePhraseImportance(phrase),
                    range: range
                ))
            }
        }
        
        // Sort by importance and return top phrases
        return Array(keyPhrases.sorted { $0.importance > $1.importance }.prefix(10))
    }
    
    // MARK: - Custom ML Model Integration
    
    private func detectCommitment(in text: String) async -> Float {
        // Use custom commitment detection model if available
        if let commitmentClassifier = commitmentClassifier {
            do {
                // Prepare input features
                let input = CommitmentInput(text: text)
                let prediction = try await commitmentClassifier.prediction(from: input)
                
                if let output = prediction.featureValue(for: "commitment_score")?.doubleValue {
                    return Float(output)
                }
            } catch {
                print("Commitment detection error: \(error)")
            }
        }
        
        // Fallback to rule-based detection
        return performRuleBasedCommitmentDetection(text)
    }
    
    private func classifyUrgency(_ text: String) async -> UrgencyLevel {
        // Use custom urgency classification model if available
        if let urgencyClassifier = urgencyClassifier {
            do {
                let input = UrgencyInput(text: text)
                let prediction = try await urgencyClassifier.prediction(from: input)
                
                if let urgencyLabel = prediction.featureValue(for: "urgency")?.stringValue {
                    return UrgencyLevel(rawValue: urgencyLabel) ?? .medium
                }
            } catch {
                print("Urgency classification error: \(error)")
            }
        }
        
        // Fallback to rule-based classification
        return performRuleBasedUrgencyClassification(text)
    }
    
    // MARK: - Private Helper Methods
    
    private func loadCustomModels() {
        // Load custom CoreML models for domain-specific tasks
        if let commitmentModelURL = Bundle.main.url(forResource: "CommitmentClassifier", withExtension: "mlmodelc") {
            commitmentClassifier = try? MLModel(contentsOf: commitmentModelURL)
        }
        
        if let urgencyModelURL = Bundle.main.url(forResource: "UrgencyClassifier", withExtension: "mlmodelc") {
            urgencyClassifier = try? MLModel(contentsOf: urgencyModelURL)
        }
    }
    
    private func performRuleBasedSentiment(_ text: String) -> SentimentAnalysis {
        let positiveWords = ["good", "great", "excellent", "amazing", "fantastic", "wonderful", "love", "like", "happy", "pleased"]
        let negativeWords = ["bad", "terrible", "awful", "hate", "dislike", "angry", "frustrated", "disappointed", "sad", "upset"]
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var score: Float = 0.0
        for word in words {
            if positiveWords.contains(word) {
                score += 1.0
            } else if negativeWords.contains(word) {
                score -= 1.0
            }
        }
        
        let normalizedScore = score / Float(words.count)
        let polarity: SentimentPolarity
        
        if normalizedScore > 0.1 {
            polarity = .positive
        } else if normalizedScore < -0.1 {
            polarity = .negative
        } else {
            polarity = .neutral
        }
        
        return SentimentAnalysis(
            polarity: polarity,
            confidence: min(abs(normalizedScore), 1.0),
            method: .ruleBased
        )
    }
    
    private func performRuleBasedCommitmentDetection(_ text: String) -> Float {
        let commitmentPhrases = [
            "i'll", "i will", "let me", "i'll get back", "i'll look into",
            "i'll send", "i'll follow up", "will do", "i'll check",
            "i'll update", "i'll reach out", "i promise", "i'll handle"
        ]
        
        let lowercaseText = text.lowercased()
        var score: Float = 0.0
        
        for phrase in commitmentPhrases {
            if lowercaseText.contains(phrase) {
                score += 0.3
            }
        }
        
        return min(score, 1.0)
    }
    
    private func performRuleBasedUrgencyClassification(_ text: String) -> UrgencyLevel {
        let urgentKeywords = ["urgent", "asap", "immediately", "emergency", "critical", "now"]
        let highKeywords = ["important", "priority", "soon", "quickly", "today"]
        let lowKeywords = ["when you can", "no rush", "eventually", "sometime"]
        
        let lowercaseText = text.lowercased()
        
        if urgentKeywords.contains(where: { lowercaseText.contains($0) }) {
            return .urgent
        } else if highKeywords.contains(where: { lowercaseText.contains($0) }) {
            return .high
        } else if lowKeywords.contains(where: { lowercaseText.contains($0) }) {
            return .low
        } else {
            return .medium
        }
    }
    
    private func mapSentimentLabel(_ label: String) -> SentimentPolarity {
        switch label.lowercased() {
        case "positive":
            return .positive
        case "negative":
            return .negative
        default:
            return .neutral
        }
    }
    
    private func mapNameTypeTag(_ tag: NLTag) -> EntityType {
        switch tag {
        case .personalName:
            return .person
        case .placeName:
            return .location
        case .organizationName:
            return .organization
        default:
            return .other
        }
    }
    
    private func analyzeLanguageCharacteristics(_ text: String) -> LanguageCharacteristics {
        let sentences = text.components(separatedBy: .newlines)
        let avgWordsPerSentence = sentences.reduce(0) { result, sentence in
            result + sentence.components(separatedBy: .whitespacesAndNewlines).count
        } / max(sentences.count, 1)
        
        let avgCharsPerWord = text.count / max(tokenizer.tokens(for: text.startIndex..<text.endIndex).count, 1)
        
        return LanguageCharacteristics(
            averageWordsPerSentence: avgWordsPerSentence,
            averageCharactersPerWord: avgCharsPerWord,
            sentenceCount: sentences.count,
            complexity: calculateTextComplexity(text)
        )
    }
    
    private func calculateTextComplexity(_ text: String) -> Float {
        // Simple readability score based on sentence and word length
        let sentences = text.components(separatedBy: .newlines)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        let avgSentenceLength = Float(words.count) / Float(max(sentences.count, 1))
        let avgWordLength = Float(text.count) / Float(max(words.count, 1))
        
        // Simplified Flesch-Kincaid grade level calculation
        return (0.39 * avgSentenceLength) + (11.8 * avgWordLength) - 15.59
    }
    
    private func calculatePhraseImportance(_ phrase: String) -> Float {
        // Simple TF-IDF-like scoring
        let words = phrase.components(separatedBy: .whitespacesAndNewlines)
        var importance: Float = 0.0
        
        // Longer phrases are generally more important
        importance += Float(words.count) * 0.1
        
        // Capitalized words might be more important (proper nouns)
        for word in words {
            if word.first?.isUppercase == true {
                importance += 0.2
            }
        }
        
        return importance
    }
}

// MARK: - Supporting Types

struct TextAnalysisResult {
    let text: String
    var language: NLLanguage = .undetermined
    var languageConfidence: [NLLanguage: Double] = [:]
    var sentiment: SentimentAnalysis = SentimentAnalysis(polarity: .neutral, confidence: 0.0, method: .ruleBased)
    var namedEntities: [NamedEntity] = []
    var linguisticTags: LinguisticAnalysis = LinguisticAnalysis()
    var commitmentScore: Float = 0.0
    var urgencyLevel: UrgencyLevel = .medium
    var keyPhrases: [KeyPhrase] = []
}

struct SentimentAnalysis {
    let polarity: SentimentPolarity
    let confidence: Float
    let method: SentimentMethod
}

enum SentimentPolarity {
    case positive
    case negative
    case neutral
}

enum SentimentMethod {
    case coreML
    case ruleBased
}

struct NamedEntity {
    let text: String
    let type: EntityType
    let range: Range<String.Index>
    let confidence: Float
}

enum EntityType {
    case person
    case location
    case organization
    case other
}

struct LinguisticAnalysis {
    var wordCount: Int = 0
    var sentences: [String] = []
    var partsOfSpeech: [String: Int] = [:]
    var languageCharacteristics: LanguageCharacteristics = LanguageCharacteristics()
}

struct LanguageCharacteristics {
    var averageWordsPerSentence: Int = 0
    var averageCharactersPerWord: Int = 0
    var sentenceCount: Int = 0
    var complexity: Float = 0.0
}

struct KeyPhrase {
    let text: String
    let importance: Float
    let range: Range<String.Index>
}

enum UrgencyLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

// MARK: - CoreML Input Types

class CommitmentInput: MLFeatureProvider {
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

class UrgencyInput: MLFeatureProvider {
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