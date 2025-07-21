#!/usr/bin/env python3
"""
Add missing AIBridge header and implementation files to Xcode project.
"""
import re
import uuid

def add_missing_ai_files():
    project_file = "/Users/neel/Desktop/Projects/insig8/macos/insig8.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for the new files
    aibridge_h_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
    aibridge_m_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
    aibridge_h_build_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
    aibridge_m_build_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
    aicompat_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
    aicompat_build_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
    
    # Find the PBXFileReference section
    file_ref_section = re.search(r'(/* Begin PBXFileReference section \*/.*?)/* End PBXFileReference section \*/', content, re.DOTALL)
    
    if file_ref_section:
        # Add AIBridge.h file reference
        new_h_ref = f'\t\t{aibridge_h_uuid} /* AIBridge.h */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = AIBridge.h; sourceTree = "<group>"; }};\n'
        
        # Add AIBridge.m file reference  
        new_m_ref = f'\t\t{aibridge_m_uuid} /* AIBridge.m */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = AIBridge.m; sourceTree = "<group>"; }};\n'
        
        # Add AICompatibilityLayer.swift file reference
        new_compat_ref = f'\t\t{aicompat_uuid} /* AICompatibilityLayer.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AICompatibilityLayer.swift; sourceTree = "<group>"; }};\n'
        
        # Insert before the end of PBXFileReference section
        end_pos = file_ref_section.end() - len('/* End PBXFileReference section */')
        content = content[:end_pos] + new_h_ref + new_m_ref + new_compat_ref + content[end_pos:]
    
    # Find the Bridge group and add the files
    bridge_group_pattern = r'(\/\* Bridge \*\/ = \{[^}]+children = \([^)]+)\);'
    bridge_match = re.search(bridge_group_pattern, content)
    
    if bridge_match:
        bridge_children = bridge_match.group(1)
        updated_bridge = bridge_children + f',\n\t\t\t\t{aibridge_h_uuid} /* AIBridge.h */,\n\t\t\t\t{aibridge_m_uuid} /* AIBridge.m */,'
        content = content.replace(bridge_children, updated_bridge)
    
    # Find the Core group and add the compatibility layer
    core_group_pattern = r'(\/\* Core \*\/ = \{[^}]+children = \([^)]+)\);'
    core_match = re.search(core_group_pattern, content)
    
    if core_match:
        core_children = core_match.group(1)
        updated_core = core_children + f',\n\t\t\t\t{aicompat_uuid} /* AICompatibilityLayer.swift */,'
        content = content.replace(core_children, updated_core)
    
    # Add to build phases - find PBXSourcesBuildPhase
    sources_section = re.search(r'(/* Begin PBXSourcesBuildPhase section \*/.*?)/* End PBXSourcesBuildPhase section \*/', content, re.DOTALL)
    
    if sources_section:
        # Find the macOS target build phase
        macos_build_phase = re.search(r'(files = \([^)]+)\);[^}]+name = Sources;[^}]+runOnlyForDeploymentPostprocessing = 0;[^}]+};', sources_section.group(1))
        
        if macos_build_phase:
            build_files = macos_build_phase.group(1)
            updated_build_files = build_files + f',\n\t\t\t\t{aibridge_m_build_uuid} /* AIBridge.m in Sources */,\n\t\t\t\t{aicompat_build_uuid} /* AICompatibilityLayer.swift in Sources */,'
            content = content.replace(build_files, updated_build_files)
            
            # Add the PBXBuildFile entries
            build_file_section = re.search(r'(/* Begin PBXBuildFile section \*/.*?)/* End PBXBuildFile section \*/', content, re.DOTALL)
            
            if build_file_section:
                new_m_build = f'\t\t{aibridge_m_build_uuid} /* AIBridge.m in Sources */ = {{isa = PBXBuildFile; fileRef = {aibridge_m_uuid} /* AIBridge.m */; }};\n'
                new_compat_build = f'\t\t{aicompat_build_uuid} /* AICompatibilityLayer.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {aicompat_uuid} /* AICompatibilityLayer.swift */; }};\n'
                
                end_pos = build_file_section.end() - len('/* End PBXBuildFile section */')
                content = content[:end_pos] + new_m_build + new_compat_build + content[end_pos:]
    
    # Write the updated project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print(f"Added AIBridge.h ({aibridge_h_uuid})")
    print(f"Added AIBridge.m ({aibridge_m_uuid})")  
    print(f"Added AICompatibilityLayer.swift ({aicompat_uuid})")
    print("Missing AI files added to Xcode project")

if __name__ == "__main__":
    add_missing_ai_files()