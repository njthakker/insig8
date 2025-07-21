#!/usr/bin/env python3
"""
Update LaunchAtLogin package from Legacy to Modern version.
"""
import re

def update_launch_at_login_package():
    project_file = "/Users/neel/Desktop/Projects/insig8/macos/insig8.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Replace the package URL from Legacy to Modern
    old_url = 'https://github.com/sindresorhus/LaunchAtLogin-Legacy'
    new_url = 'https://github.com/sindresorhus/LaunchAtLogin-Modern'
    
    if old_url in content:
        content = content.replace(old_url, new_url)
        print(f"Updated package URL: {old_url} -> {new_url}")
    else:
        print("Old package URL not found - no changes needed")
    
    # Update the package reference name if needed
    old_ref = 'XCRemoteSwiftPackageReference "LaunchAtLogin-Legacy"'
    new_ref = 'XCRemoteSwiftPackageReference "LaunchAtLogin-Modern"'
    
    if old_ref in content:
        content = content.replace(old_ref, new_ref)
        print(f"Updated package reference: {old_ref} -> {new_ref}")
    
    # Write the updated project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("Project file updated to use LaunchAtLogin-Modern")

if __name__ == "__main__":
    update_launch_at_login_package()