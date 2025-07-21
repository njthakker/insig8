import React, { useState, useEffect } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, StyleSheet } from 'react-native';
import { AIService, Commitment, SearchResult, AIStatus } from '../../services/ai.service';

interface AITestPanelProps {
  onClose?: () => void;
}

export const AITestPanel: React.FC<AITestPanelProps> = ({ onClose }) => {
  const [aiStatus, setAIStatus] = useState<AIStatus | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [commitments, setCommitments] = useState<Commitment[]>([]);
  const [testMessage, setTestMessage] = useState('I\'ll get back to you on this shortly');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    initializeAI();
    loadCommitments();
  }, []);

  const initializeAI = async () => {
    try {
      setIsLoading(true);
      await AIService.initialize();
      const status = await AIService.getStatus();
      setAIStatus(status);
      setError(null);
    } catch (err) {
      setError(`Failed to initialize AI: ${err}`);
    } finally {
      setIsLoading(false);
    }
  };

  const loadCommitments = async () => {
    try {
      const activeCommitments = await AIService.getActiveCommitments();
      setCommitments(activeCommitments);
    } catch (err) {
      console.error('Failed to load commitments:', err);
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;

    try {
      setIsLoading(true);
      const results = await AIService.semanticSearch(searchQuery, 10);
      setSearchResults(results);
      setError(null);
    } catch (err) {
      setError(`Search failed: ${err}`);
    } finally {
      setIsLoading(false);
    }
  };

  const testCommitmentDetection = async () => {
    try {
      setIsLoading(true);
      const commitment = await AIService.analyzeMessage(
        testMessage,
        'test',
        'TestUser',
        'test-thread'
      );
      
      if (commitment) {
        setCommitments(prev => [commitment, ...prev]);
        setError(null);
      } else {
        setError('No commitment detected in the message');
      }
    } catch (err) {
      setError(`Commitment detection failed: ${err}`);
    } finally {
      setIsLoading(false);
    }
  };

  const startScreenMonitoring = async () => {
    try {
      await AIService.startScreenMonitoring();
      const status = await AIService.getStatus();
      setAIStatus(status);
    } catch (err) {
      setError(`Failed to start screen monitoring: ${err}`);
    }
  };

  const stopScreenMonitoring = async () => {
    try {
      await AIService.stopScreenMonitoring();
      const status = await AIService.getStatus();
      setAIStatus(status);
    } catch (err) {
      setError(`Failed to stop screen monitoring: ${err}`);
    }
  };

  const updateCommitmentStatus = async (commitmentId: string, status: Commitment['status']) => {
    try {
      await AIService.updateCommitmentStatus(commitmentId, status);
      await loadCommitments();
    } catch (err) {
      setError(`Failed to update commitment: ${err}`);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>AI Test Panel</Text>
        {onClose && (
          <TouchableOpacity onPress={onClose} style={styles.closeButton}>
            <Text style={styles.closeText}>×</Text>
          </TouchableOpacity>
        )}
      </View>

      <ScrollView style={styles.content}>
        {/* AI Status */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>AI Status</Text>
          {aiStatus ? (
            <View style={styles.statusContainer}>
              <Text style={styles.statusText}>
                Initialized: {aiStatus.initialized ? '✅' : '❌'}
              </Text>
              <Text style={styles.statusText}>
                Screen Monitoring: {aiStatus.screenMonitoring ? '✅' : '❌'}
              </Text>
              <Text style={styles.statusText}>
                Meeting Recording: {aiStatus.meetingRecording ? '✅' : '❌'}
              </Text>
              <Text style={styles.statusText}>Version: {aiStatus.version}</Text>
            </View>
          ) : (
            <Text>Loading status...</Text>
          )}
        </View>

        {/* Screen Monitoring Controls */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Screen Monitoring</Text>
          <View style={styles.buttonRow}>
            <TouchableOpacity 
              style={styles.button} 
              onPress={startScreenMonitoring}
              disabled={isLoading}
            >
              <Text style={styles.buttonText}>Start Monitoring</Text>
            </TouchableOpacity>
            <TouchableOpacity 
              style={[styles.button, styles.secondaryButton]} 
              onPress={stopScreenMonitoring}
              disabled={isLoading}
            >
              <Text style={styles.buttonText}>Stop Monitoring</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Commitment Detection Test */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Test Commitment Detection</Text>
          <TextInput
            style={styles.textInput}
            value={testMessage}
            onChangeText={setTestMessage}
            placeholder="Enter a message to analyze..."
            multiline
          />
          <TouchableOpacity 
            style={styles.button} 
            onPress={testCommitmentDetection}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>Analyze Message</Text>
          </TouchableOpacity>
        </View>

        {/* Search Test */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Search Test</Text>
          <TextInput
            style={styles.textInput}
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Enter search query..."
          />
          <TouchableOpacity 
            style={styles.button} 
            onPress={handleSearch}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>Search</Text>
          </TouchableOpacity>
          
          {searchResults.length > 0 && (
            <View style={styles.results}>
              <Text style={styles.resultsTitle}>Search Results:</Text>
              {searchResults.map((result, index) => (
                <View key={index} style={styles.resultItem}>
                  <Text style={styles.resultTitle}>{result.title}</Text>
                  <Text style={styles.resultContent} numberOfLines={2}>
                    {result.content}
                  </Text>
                  <Text style={styles.resultMeta}>
                    Type: {result.type} | Score: {result.relevanceScore.toFixed(2)}
                  </Text>
                </View>
              ))}
            </View>
          )}
        </View>

        {/* Active Commitments */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Active Commitments ({commitments.length})</Text>
          {commitments.map((commitment) => (
            <View key={commitment.id} style={styles.commitmentItem}>
              <Text style={styles.commitmentText}>{commitment.description}</Text>
              <Text style={styles.commitmentMeta}>
                To: {commitment.recipient} | Status: {commitment.status}
              </Text>
              <View style={styles.commitmentActions}>
                <TouchableOpacity 
                  style={[styles.actionButton, styles.completeButton]}
                  onPress={() => updateCommitmentStatus(commitment.id, 'completed')}
                >
                  <Text style={styles.actionButtonText}>Complete</Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  style={[styles.actionButton, styles.dismissButton]}
                  onPress={() => updateCommitmentStatus(commitment.id, 'dismissed')}
                >
                  <Text style={styles.actionButtonText}>Dismiss</Text>
                </TouchableOpacity>
              </View>
            </View>
          ))}
        </View>

        {/* Error Display */}
        {error && (
          <View style={styles.errorContainer}>
            <Text style={styles.errorText}>{error}</Text>
            <TouchableOpacity 
              style={styles.clearErrorButton}
              onPress={() => setError(null)}
            >
              <Text style={styles.clearErrorText}>Clear</Text>
            </TouchableOpacity>
          </View>
        )}

        {/* Loading Indicator */}
        {isLoading && (
          <View style={styles.loadingContainer}>
            <Text style={styles.loadingText}>Loading...</Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a1a',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#333',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#fff',
  },
  closeButton: {
    width: 30,
    height: 30,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#333',
    borderRadius: 15,
  },
  closeText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  content: {
    flex: 1,
    padding: 16,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
  },
  statusContainer: {
    backgroundColor: '#2a2a2a',
    padding: 12,
    borderRadius: 8,
  },
  statusText: {
    color: '#ccc',
    marginBottom: 4,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    flex: 1,
  },
  secondaryButton: {
    backgroundColor: '#666',
  },
  buttonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  textInput: {
    backgroundColor: '#2a2a2a',
    color: '#fff',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
    minHeight: 40,
  },
  results: {
    marginTop: 16,
  },
  resultsTitle: {
    color: '#fff',
    fontWeight: 'bold',
    marginBottom: 8,
  },
  resultItem: {
    backgroundColor: '#2a2a2a',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
  },
  resultTitle: {
    color: '#fff',
    fontWeight: 'bold',
    marginBottom: 4,
  },
  resultContent: {
    color: '#ccc',
    marginBottom: 4,
  },
  resultMeta: {
    color: '#888',
    fontSize: 12,
  },
  commitmentItem: {
    backgroundColor: '#2a2a2a',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
  },
  commitmentText: {
    color: '#fff',
    marginBottom: 4,
  },
  commitmentMeta: {
    color: '#888',
    fontSize: 12,
    marginBottom: 8,
  },
  commitmentActions: {
    flexDirection: 'row',
    gap: 8,
  },
  actionButton: {
    padding: 8,
    borderRadius: 6,
    flex: 1,
    alignItems: 'center',
  },
  completeButton: {
    backgroundColor: '#34C759',
  },
  dismissButton: {
    backgroundColor: '#FF3B30',
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
  },
  errorContainer: {
    backgroundColor: '#FF3B30',
    padding: 12,
    borderRadius: 8,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  errorText: {
    color: '#fff',
    flex: 1,
  },
  clearErrorButton: {
    padding: 4,
  },
  clearErrorText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  loadingContainer: {
    backgroundColor: '#2a2a2a',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  loadingText: {
    color: '#fff',
  },
});