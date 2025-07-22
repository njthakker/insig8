import Foundation
import React

@objc(AIBridge)
class AIBridge: NSObject {
    private let aiManager = AIAgentManager.shared
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // MARK: - AI Initialization
    
    @objc
    func initializeAI(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                try await aiManager.initialize()
                await MainActor.run {
                    resolve(["success": true, "message": "AI system initialized successfully"])
                }
            } catch {
                await MainActor.run {
                    reject("AI_INIT_ERROR", "Failed to initialize AI system: \(error.localizedDescription)", error)
                }
            }
        }
    }
    
    // MARK: - Commitment Tracking
    
    @objc
    func analyzeMessage(
        _ message: String,
        platform: String,
        sender: String,
        threadId: String?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            let context = MessageContext(
                platform: platform,
                sender: sender,
                timestamp: Date(),
                threadId: threadId
            )
            
            let commitment = await aiManager.analyzeMessage(message, context: context)
            
            await MainActor.run {
                if let commitment = commitment {
                    resolve(commitmentToDict(commitment))
                } else {
                    resolve(NSNull())
                }
            }
        }
    }
    
    @objc
    func getActiveCommitments(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        let commitments = aiManager.getActiveCommitments()
        let commitmentsArray = commitments.map { commitmentToDict($0) }
        resolve(commitmentsArray)
    }
    
    @objc
    func updateCommitmentStatus(
        _ commitmentId: String,
        status: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let uuid = UUID(uuidString: commitmentId),
              let commitmentStatus = CommitmentStatus(rawValue: status) else {
            reject("INVALID_PARAMS", "Invalid commitment ID or status", nil)
            return
        }
        
        Task {
            await aiManager.updateCommitmentStatus(uuid, status: commitmentStatus)
            await MainActor.run {
                resolve(["success": true])
            }
        }
    }
    
    @objc
    func snoozeCommitment(
        _ commitmentId: String,
        until: Double,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let uuid = UUID(uuidString: commitmentId) else {
            reject("INVALID_PARAMS", "Invalid commitment ID", nil)
            return
        }
        
        let snoozeDate = Date(timeIntervalSince1970: until / 1000)
        
        Task {
            await aiManager.snoozeCommitment(uuid, until: snoozeDate)
            await MainActor.run {
                resolve(["success": true])
            }
        }
    }
    
    // MARK: - Meeting Processing
    
    @objc
    func startMeetingRecording(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                try await aiManager.startMeetingRecording()
                await MainActor.run {
                    resolve(["success": true, "message": "Meeting recording started"])
                }
            } catch {
                await MainActor.run {
                    reject("MEETING_ERROR", "Failed to start meeting recording: \(error.localizedDescription)", error)
                }
            }
        }
    }
    
    @objc
    func stopMeetingRecording(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                let meetingSession = try await aiManager.stopMeetingRecording()
                await MainActor.run {
                    if let meeting = meetingSession {
                        resolve(meetingSessionToDict(meeting))
                    } else {
                        resolve(NSNull())
                    }
                }
            } catch {
                await MainActor.run {
                    reject("MEETING_ERROR", "Failed to stop meeting recording: \(error.localizedDescription)", error)
                }
            }
        }
    }
    
    @objc
    func getMeetingHistory(
        _ limit: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let meetings = aiManager.getMeetingHistory(limit: limit.intValue)
        let meetingsArray = meetings.map { meetingSessionToDict($0) }
        resolve(meetingsArray)
    }
    
    // MARK: - Search Functionality
    
    @objc
    func semanticSearch(
        _ query: String,
        limit: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            let results = await aiManager.semanticSearch(query)
            let limitedResults = Array(results.prefix(limit.intValue))
            
            await MainActor.run {
                let resultsArray = limitedResults.map { searchResultToDict($0) }
                resolve(resultsArray)
            }
        }
    }
    
    @objc
    func globalSearch(
        _ query: String,
        limit: NSNumber,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            let results = await aiManager.globalSearch(query, limit: limit.intValue)
            
            await MainActor.run {
                if let results = results {
                    resolve(globalSearchResultsToDict(results))
                } else {
                    resolve(["totalResults": 0, "results": []])
                }
            }
        }
    }
    
    @objc
    func searchCommitments(
        _ query: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            let commitments = await aiManager.searchCommitments(query)
            
            await MainActor.run {
                let commitmentsArray = commitments.map { commitmentToDict($0) }
                resolve(commitmentsArray)
            }
        }
    }
    
    @objc
    func searchMeetings(
        _ query: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            let meetings = await aiManager.searchMeetings(query)
            
            await MainActor.run {
                let meetingsArray = meetings.map { meetingSessionToDict($0) }
                resolve(meetingsArray)
            }
        }
    }
    
    @objc
    func searchClipboard(
        _ query: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            let clipboardItems = await aiManager.searchClipboardHistory(query)
            
            await MainActor.run {
                let itemsArray = clipboardItems.map { clipboardItemToDict($0) }
                resolve(itemsArray)
            }
        }
    }
    
    // MARK: - Screen Monitoring
    
    @objc
    func startScreenMonitoring(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                try await aiManager.startScreenMonitoring()
                await MainActor.run {
                    resolve(["success": true, "message": "Screen monitoring started"])
                }
            } catch {
                await MainActor.run {
                    reject("SCREEN_MONITOR_ERROR", "Failed to start screen monitoring: \(error.localizedDescription)", error)
                }
            }
        }
    }
    
    @objc
    func stopScreenMonitoring(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        aiManager.stopScreenMonitoring()
        resolve(["success": true, "message": "Screen monitoring stopped"])
    }
    
    @objc
    func getUnrespondedMessages(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        Task {
            let unrespondedMessages = await aiManager.detectUnrespondedMessages()
            
            await MainActor.run {
                let messagesArray = unrespondedMessages.map { unrespondedMessageToDict($0) }
                resolve(messagesArray)
            }
        }
    }
    
    // MARK: - Utility Functions
    
    @objc
    func getAIStatus(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        // Return current AI system status
        resolve([
            "initialized": true, // Would check actual initialization state
            "screenMonitoring": false, // Would check actual monitoring state
            "meetingRecording": false, // Would check actual recording state
            "version": "1.0.0"
        ])
    }
    
    // MARK: - Private Helper Methods
    
    private func commitmentToDict(_ commitment: Commitment) -> [String: Any] {
        return [
            "id": commitment.id.uuidString,
            "description": commitment.description,
            "recipient": commitment.recipient,
            "status": commitment.status.rawValue,
            "priority": commitment.priority.rawValue,
            "urgencyScore": commitment.urgencyScore,
            "dueDate": commitment.dueDate?.timeIntervalSince1970 ?? NSNull(),
            "createdAt": commitment.createdAt.timeIntervalSince1970,
            "updatedAt": commitment.updatedAt.timeIntervalSince1970,
            "source": commitmentSourceToDict(commitment.source),
            "context": commitment.context
        ]
    }
    
    private func commitmentSourceToDict(_ source: CommitmentSource) -> [String: Any] {
        switch source {
        case .slack(let channelId):
            return ["type": "slack", "channelId": channelId]
        case .email(let messageId):
            return ["type": "email", "messageId": messageId]
        case .teams(let conversationId):
            return ["type": "teams", "conversationId": conversationId]
        case .manual:
            return ["type": "manual"]
        case .screenCapture(let timestamp):
            return ["type": "screenCapture", "timestamp": timestamp.timeIntervalSince1970]
        }
    }
    
    private func meetingSessionToDict(_ meeting: MeetingSession) -> [String: Any] {
        return [
            "id": meeting.id.uuidString,
            "title": meeting.title,
            "startTime": meeting.startTime.timeIntervalSince1970,
            "endTime": meeting.endTime?.timeIntervalSince1970 ?? NSNull(),
            "participants": meeting.participants,
            "summary": meeting.summary,
            "transcript": meeting.transcript,
            "actionItems": meeting.actionItems.map { actionItemToDict($0) },
            "createdAt": meeting.createdAt.timeIntervalSince1970
        ]
    }
    
    private func actionItemToDict(_ actionItem: ActionItem) -> [String: Any] {
        return [
            "id": actionItem.id.uuidString,
            "description": actionItem.description,
            "assignee": actionItem.assignee ?? NSNull(),
            "dueDate": actionItem.dueDate?.timeIntervalSince1970 ?? NSNull(),
            "status": actionItem.status.rawValue,
            "priority": actionItem.priority.rawValue,
            "meetingId": actionItem.meetingId.uuidString,
            "createdAt": actionItem.createdAt.timeIntervalSince1970,
            "updatedAt": actionItem.updatedAt.timeIntervalSince1970
        ]
    }
    
    private func searchResultToDict(_ result: SearchResult) -> [String: Any] {
        return [
            "id": result.id.uuidString,
            "title": result.title,
            "content": result.content,
            "type": result.type.rawValue,
            "relevanceScore": result.relevanceScore,
            "timestamp": result.timestamp.timeIntervalSince1970,
            "metadata": result.metadata
        ]
    }
    
    private func clipboardItemToDict(_ item: ClipboardItem) -> [String: Any] {
        return [
            "id": item.id.uuidString,
            "content": item.content,
            "contentType": item.contentType.rawValue,
            "timestamp": item.timestamp.timeIntervalSince1970,
            "sourceApp": item.sourceApp ?? NSNull()
        ]
    }
    
    private func unrespondedMessageToDict(_ message: UnrespondedMessage) -> [String: Any] {
        return [
            "id": message.id.uuidString,
            "sender": message.sender,
            "platform": message.platform,
            "content": message.content,
            "timestamp": message.timestamp.timeIntervalSince1970,
            "expiryHours": message.expiryHours
        ]
    }
    
    private func globalSearchResultsToDict(_ results: GlobalSearchResults) -> [String: Any] {
        return [
            "totalResults": results.totalResults,
            "semanticResults": results.semanticResults.map { searchResultToDict($0) },
            "commitments": results.commitments.map { commitmentToDict($0) },
            "meetings": results.meetings.map { meetingSessionToDict($0) },
            "clipboardItems": results.clipboardItems.map { clipboardItemToDict($0) }
        ]
    }
}