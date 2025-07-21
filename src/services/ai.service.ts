import { NativeModules } from 'react-native';

const { AIBridge } = NativeModules;

export interface Commitment {
  id: string;
  description: string;
  recipient: string;
  status: 'pending' | 'in_progress' | 'completed' | 'overdue' | 'dismissed' | 'snoozed';
  priority: number;
  urgencyScore: number;
  dueDate?: number;
  createdAt: number;
  updatedAt: number;
  source: CommitmentSource;
  context: string;
}

export interface CommitmentSource {
  type: 'slack' | 'email' | 'teams' | 'manual' | 'screenCapture';
  channelId?: string;
  messageId?: string;
  conversationId?: string;
  timestamp?: number;
}

export interface MeetingSession {
  id: string;
  title: string;
  startTime: number;
  endTime?: number;
  participants: string[];
  summary: string;
  transcript: string;
  actionItems: ActionItem[];
  createdAt: number;
}

export interface ActionItem {
  id: string;
  description: string;
  assignee?: string;
  dueDate?: number;
  status: 'open' | 'in_progress' | 'completed' | 'cancelled';
  priority: number;
  meetingId: string;
  createdAt: number;
  updatedAt: number;
}

export interface SearchResult {
  id: string;
  title: string;
  content: string;
  type: 'commitment' | 'meeting' | 'screen_capture' | 'clipboard_item' | 'browser_history';
  relevanceScore: number;
  timestamp: number;
  metadata: Record<string, any>;
}

export interface ClipboardItem {
  id: string;
  content: string;
  contentType: 'text' | 'url' | 'file' | 'image';
  timestamp: number;
  sourceApp?: string;
}

export interface UnrespondedMessage {
  id: string;
  sender: string;
  platform: string;
  content: string;
  timestamp: number;
  expiryHours: number;
}

export interface GlobalSearchResults {
  totalResults: number;
  semanticResults: SearchResult[];
  commitments: Commitment[];
  meetings: MeetingSession[];
  clipboardItems: ClipboardItem[];
}

export interface AIStatus {
  initialized: boolean;
  screenMonitoring: boolean;
  meetingRecording: boolean;
  version: string;
}

export class AIService {
  /**
   * Initialize the AI system
   */
  static async initialize(): Promise<{ success: boolean; message: string }> {
    try {
      return await AIBridge.initializeAI();
    } catch (error) {
      console.error('Failed to initialize AI:', error);
      throw error;
    }
  }

  // MARK: - Commitment Tracking

  /**
   * Analyze a message for commitments
   */
  static async analyzeMessage(
    message: string,
    platform: string,
    sender: string,
    threadId?: string
  ): Promise<Commitment | null> {
    try {
      return await AIBridge.analyzeMessage(message, platform, sender, threadId || null);
    } catch (error) {
      console.error('Failed to analyze message:', error);
      throw error;
    }
  }

  /**
   * Get all active commitments
   */
  static async getActiveCommitments(): Promise<Commitment[]> {
    try {
      return await AIBridge.getActiveCommitments();
    } catch (error) {
      console.error('Failed to get active commitments:', error);
      throw error;
    }
  }

  /**
   * Update commitment status
   */
  static async updateCommitmentStatus(
    commitmentId: string,
    status: Commitment['status']
  ): Promise<{ success: boolean }> {
    try {
      return await AIBridge.updateCommitmentStatus(commitmentId, status);
    } catch (error) {
      console.error('Failed to update commitment status:', error);
      throw error;
    }
  }

  /**
   * Snooze a commitment until a specific date
   */
  static async snoozeCommitment(
    commitmentId: string,
    until: Date
  ): Promise<{ success: boolean }> {
    try {
      return await AIBridge.snoozeCommitment(commitmentId, until.getTime());
    } catch (error) {
      console.error('Failed to snooze commitment:', error);
      throw error;
    }
  }

  // MARK: - Meeting Processing

  /**
   * Start meeting recording and transcription
   */
  static async startMeetingRecording(): Promise<{ success: boolean; message: string }> {
    try {
      return await AIBridge.startMeetingRecording();
    } catch (error) {
      console.error('Failed to start meeting recording:', error);
      throw error;
    }
  }

  /**
   * Stop meeting recording and get the session
   */
  static async stopMeetingRecording(): Promise<MeetingSession | null> {
    try {
      return await AIBridge.stopMeetingRecording();
    } catch (error) {
      console.error('Failed to stop meeting recording:', error);
      throw error;
    }
  }

  /**
   * Get meeting history
   */
  static async getMeetingHistory(limit: number = 10): Promise<MeetingSession[]> {
    try {
      return await AIBridge.getMeetingHistory(limit);
    } catch (error) {
      console.error('Failed to get meeting history:', error);
      throw error;
    }
  }

  // MARK: - Search Functionality

  /**
   * Perform semantic search across all data
   */
  static async semanticSearch(query: string, limit: number = 10): Promise<SearchResult[]> {
    try {
      return await AIBridge.semanticSearch(query, limit);
    } catch (error) {
      console.error('Failed to perform semantic search:', error);
      throw error;
    }
  }

  /**
   * Perform global search across all data sources
   */
  static async globalSearch(query: string, limit: number = 20): Promise<GlobalSearchResults> {
    try {
      return await AIBridge.globalSearch(query, limit);
    } catch (error) {
      console.error('Failed to perform global search:', error);
      throw error;
    }
  }

  /**
   * Search commitments specifically
   */
  static async searchCommitments(query: string): Promise<Commitment[]> {
    try {
      return await AIBridge.searchCommitments(query);
    } catch (error) {
      console.error('Failed to search commitments:', error);
      throw error;
    }
  }

  /**
   * Search meetings specifically
   */
  static async searchMeetings(query: string): Promise<MeetingSession[]> {
    try {
      return await AIBridge.searchMeetings(query);
    } catch (error) {
      console.error('Failed to search meetings:', error);
      throw error;
    }
  }

  /**
   * Search clipboard history
   */
  static async searchClipboard(query: string): Promise<ClipboardItem[]> {
    try {
      return await AIBridge.searchClipboard(query);
    } catch (error) {
      console.error('Failed to search clipboard:', error);
      throw error;
    }
  }

  // MARK: - Screen Monitoring

  /**
   * Start screen monitoring for context awareness
   */
  static async startScreenMonitoring(): Promise<{ success: boolean; message: string }> {
    try {
      return await AIBridge.startScreenMonitoring();
    } catch (error) {
      console.error('Failed to start screen monitoring:', error);
      throw error;
    }
  }

  /**
   * Stop screen monitoring
   */
  static async stopScreenMonitoring(): Promise<{ success: boolean; message: string }> {
    try {
      return await AIBridge.stopScreenMonitoring();
    } catch (error) {
      console.error('Failed to stop screen monitoring:', error);
      throw error;
    }
  }

  /**
   * Get unresponded messages detected from screen monitoring
   */
  static async getUnrespondedMessages(): Promise<UnrespondedMessage[]> {
    try {
      return await AIBridge.getUnrespondedMessages();
    } catch (error) {
      console.error('Failed to get unresponded messages:', error);
      throw error;
    }
  }

  // MARK: - Utility Functions

  /**
   * Get AI system status
   */
  static async getStatus(): Promise<AIStatus> {
    try {
      return await AIBridge.getAIStatus();
    } catch (error) {
      console.error('Failed to get AI status:', error);
      throw error;
    }
  }

  // MARK: - Helper Methods

  /**
   * Format a commitment for display
   */
  static formatCommitment(commitment: Commitment): string {
    const dueDate = commitment.dueDate ? new Date(commitment.dueDate) : null;
    const dueDateStr = dueDate ? ` (due ${dueDate.toLocaleDateString()})` : '';
    return `${commitment.description} - ${commitment.recipient}${dueDateStr}`;
  }

  /**
   * Get priority color for UI
   */
  static getPriorityColor(priority: number): string {
    switch (priority) {
      case 4: return '#FF4444'; // Urgent - Red
      case 3: return '#FF8800'; // High - Orange
      case 2: return '#FFBB00'; // Medium - Yellow
      case 1: return '#00BB00'; // Low - Green
      default: return '#888888'; // Unknown - Gray
    }
  }

  /**
   * Get status color for UI
   */
  static getStatusColor(status: Commitment['status']): string {
    switch (status) {
      case 'pending': return '#FFBB00'; // Yellow
      case 'in_progress': return '#0088FF'; // Blue
      case 'completed': return '#00BB00'; // Green
      case 'overdue': return '#FF4444'; // Red
      case 'dismissed': return '#888888'; // Gray
      case 'snoozed': return '#BB88FF'; // Purple
      default: return '#888888'; // Gray
    }
  }

  /**
   * Check if commitment is overdue
   */
  static isOverdue(commitment: Commitment): boolean {
    if (!commitment.dueDate) return false;
    return Date.now() > commitment.dueDate && commitment.status !== 'completed';
  }

  /**
   * Get relative time string
   */
  static getRelativeTime(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return 'Just now';
  }
}