#!/usr/bin/env python3
"""
Fix AI file path references in Xcode project.pbxproj file.
"""

def fix_file_references():
    project_file = "/Users/neel/Desktop/Projects/insig8/macos/insig8.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Define file path corrections - map filename to full path
    path_corrections = {
        'path = AIAgentManager.swift;': 'path = Core/AIAgentManager.swift;',
        'path = CommitmentTracker.swift;': 'path = Agents/CommitmentTracker.swift;',
        'path = IntelligentSearchEngine.swift;': 'path = Agents/IntelligentSearchEngine.swift;',
        'path = MeetingProcessor.swift;': 'path = Agents/MeetingProcessor.swift;',
        'path = ScreenMonitor.swift;': 'path = Agents/ScreenMonitor.swift;',
        'path = AIBridge.swift;': 'path = Bridge/AIBridge.swift;',
        'path = AIBridge.h;': 'path = Bridge/AIBridge.h;',
        'path = AIBridge.m;': 'path = Bridge/AIBridge.m;',
        'path = AIDataModels.swift;': 'path = Data/AIDataModels.swift;',
        'path = VectorDatabase.swift;': 'path = Vector/VectorDatabase.swift;',
        'path = AICompatibilityLayer.swift;': 'path = Core/AICompatibilityLayer.swift;'
    }
    
    # Apply corrections
    for old_path, new_path in path_corrections.items():
        if old_path in content:
            content = content.replace(old_path, new_path)
            print(f"Fixed: {old_path} -> {new_path}")
        else:
            print(f"Not found: {old_path}")
    
    # Write the corrected project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("File path references corrected in Xcode project")

if __name__ == "__main__":
    fix_file_references()