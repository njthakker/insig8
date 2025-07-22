#!/usr/bin/env python3
import os
import uuid
import re

def generate_pbx_id():
    """Generate a unique 24-character hex ID for Xcode project items"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def add_files_to_xcode_project():
    """Add missing AI enhancement files to the Xcode project"""
    
    project_path = "insig8.xcodeproj/project.pbxproj"
    
    # List of new AI files that need to be added
    new_ai_files = [
        "AI/Core/EnhancedTextProcessor.swift",
        "AI/Core/CoreMLManager.swift", 
        "AI/Core/AISharedTypes.swift",
        "managers/LaunchAtLoginManager.swift"
    ]
    
    # Read the project file
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Find the insig8-macOS directory in the project structure
    insig8_macos_group_match = re.search(r'([A-F0-9]{24}) /\* insig8-macOS \*/ = {[^}]+children = \((.*?)\);', content, re.DOTALL)
    if not insig8_macos_group_match:
        print("Could not find insig8-macOS group in project")
        return False
    
    insig8_group_id = insig8_macos_group_match.group(1)
    
    # Add file references
    file_references_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?)/\* End PBXFileReference section \*/', content, re.DOTALL)
    if not file_references_section:
        print("Could not find PBXFileReference section")
        return False
    
    new_file_refs = []
    new_build_files = []
    
    for file_path in new_ai_files:
        file_id = generate_pbx_id()
        build_file_id = generate_pbx_id()
        filename = os.path.basename(file_path)
        
        # Create file reference
        file_ref = f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{file_path}\"; sourceTree = \"<group>\"; }};"
        new_file_refs.append((file_id, file_ref))
        
        # Create build file entry
        build_file = f"\t\t{build_file_id} = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};"
        new_build_files.append((build_file_id, build_file))
    
    # Insert file references
    file_ref_end = file_references_section.end() - len("/* End PBXFileReference section */")
    for file_id, file_ref in new_file_refs:
        content = content[:file_ref_end] + file_ref + "\n" + content[file_ref_end:]
        file_ref_end += len(file_ref) + 1
    
    # Add build files
    build_files_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?)/\* End PBXBuildFile section \*/', content, re.DOTALL)
    if build_files_section:
        build_file_end = build_files_section.end() - len("/* End PBXBuildFile section */")
        for build_file_id, build_file in new_build_files:
            content = content[:build_file_end] + build_file + "\n" + content[build_file_end:]
            build_file_end += len(build_file) + 1
    
    # Add files to Sources build phase
    sources_build_phase_match = re.search(r'([A-F0-9]{24}) /\* Sources \*/ = {[^}]+files = \((.*?)\);', content, re.DOTALL)
    if sources_build_phase_match:
        sources_files = sources_build_phase_match.group(2)
        build_phase_start = sources_build_phase_match.start(2)
        build_phase_end = sources_build_phase_match.end(2)
        
        # Add new build file references to sources
        new_source_entries = []
        for i, (build_file_id, _) in enumerate(new_build_files):
            filename = new_ai_files[i].split('/')[-1].replace('.swift', '')
            entry = f"\t\t\t\t{build_file_id} /* {filename}.swift in Sources */,"
            new_source_entries.append(entry)
        
        new_sources = sources_files + "\n" + "\n".join(new_source_entries)
        content = content[:build_phase_start] + new_sources + content[build_phase_end:]
    
    # Write back the modified project file
    with open(project_path, 'w') as f:
        f.write(content)
    
    print(f"Successfully added {len(new_ai_files)} files to Xcode project")
    return True

if __name__ == "__main__":
    if add_files_to_xcode_project():
        print("Files added successfully!")
    else:
        print("Failed to add files to project")