#!/usr/bin/env python3
"""
Fix AI file paths in Xcode project after they were added with incorrect references.
"""
import re

def fix_ai_file_paths():
    project_file = "/Users/neel/Desktop/Projects/insig8/macos/insig8.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Define path corrections
    path_corrections = {
        'insig8-macOS/AI/AIAgentManager.swift': 'insig8-macOS/AI/Core/AIAgentManager.swift',
        'insig8-macOS/AI/CommitmentTracker.swift': 'insig8-macOS/AI/Agents/CommitmentTracker.swift',
        'insig8-macOS/AI/IntelligentSearchEngine.swift': 'insig8-macOS/AI/Agents/IntelligentSearchEngine.swift',
        'insig8-macOS/AI/MeetingProcessor.swift': 'insig8-macOS/AI/Agents/MeetingProcessor.swift',
        'insig8-macOS/AI/ScreenMonitor.swift': 'insig8-macOS/AI/Agents/ScreenMonitor.swift',
        'insig8-macOS/AI/AIBridge.swift': 'insig8-macOS/AI/Bridge/AIBridge.swift',
        'insig8-macOS/AI/AIDataModels.swift': 'insig8-macOS/AI/Data/AIDataModels.swift',
        'insig8-macOS/AI/VectorDatabase.swift': 'insig8-macOS/AI/Vector/VectorDatabase.swift'
    }
    
    # Apply corrections
    for old_path, new_path in path_corrections.items():
        content = content.replace(old_path, new_path)
        print(f"Fixed: {old_path} -> {new_path}")
    
    # Write the corrected project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("AI file paths corrected in Xcode project")

if __name__ == "__main__":
    fix_ai_file_paths()