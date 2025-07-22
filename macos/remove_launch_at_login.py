#!/usr/bin/env python3
"""
Remove LaunchAtLogin package references from Xcode project to fix beta build issues
"""

import re

def remove_launch_at_login_references(project_file):
    """Remove all LaunchAtLogin references from project.pbxproj"""
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # LaunchAtLogin specific UUIDs and patterns to remove
    patterns_to_remove = [
        # LaunchAtLogin framework reference
        r'\s*7065EBBF2CDB8C2B008C0A74 /\* LaunchAtLogin in Frameworks \*/ = \{isa = PBXBuildFile; productRef = 7065EBBE2CDB8C2B008C0A74 /\* LaunchAtLogin \*/; \};.*\n',
        
        # LaunchAtLogin in frameworks build phase
        r'\s*7065EBBF2CDB8C2B008C0A74 /\* LaunchAtLogin in Frameworks \*/,?\n',
        
        # LaunchAtLogin product reference
        r'\s*7065EBBE2CDB8C2B008C0A74 /\* LaunchAtLogin \*/,?\n',
        
        # LaunchAtLogin package reference 
        r'\s*7065EBBD2CDB8C2B008C0A74 /\* XCRemoteSwiftPackageReference "LaunchAtLogin-Modern" \*/,?\n',
        
        # LaunchAtLogin package definition block
        r'\s*7065EBBD2CDB8C2B008C0A74 /\* XCRemoteSwiftPackageReference "LaunchAtLogin-Modern" \*/ = \{[^}]*repositoryURL = "https://github\.com/sindresorhus/LaunchAtLogin-Modern";[^}]*\};\n',
        
        # LaunchAtLogin product definition block
        r'\s*7065EBBE2CDB8C2B008C0A74 /\* LaunchAtLogin \*/ = \{[^}]*package = 7065EBBD2CDB8C2B008C0A74[^}]*\};\n',
        
        # LaunchAtLogin helper script
        r'[^}]*shellScript = ".*LaunchAtLogin_LaunchAtLogin\.bundle.*";\n',
    ]
    
    # Apply all removal patterns
    for pattern in patterns_to_remove:
        content = re.sub(pattern, '', content)
    
    # Clean up any trailing commas that might be left
    content = re.sub(r',(\s*\n\s*\);)', r'\1', content)
    
    # Clean up any double newlines
    content = re.sub(r'\n\n+', '\n\n', content)
    
    # Write back the cleaned content
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Removed LaunchAtLogin package references from project.pbxproj")

if __name__ == "__main__":
    project_file = "insig8.xcodeproj/project.pbxproj"
    remove_launch_at_login_references(project_file)
    print("🔧 LaunchAtLogin package temporarily removed to fix Xcode beta build issues")
    print("📝 TODO: Re-add LaunchAtLogin once Xcode beta issues are resolved")