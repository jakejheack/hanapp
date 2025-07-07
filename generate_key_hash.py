#!/usr/bin/env python3
"""
Script to generate Facebook key hash for Android app
"""
import subprocess
import base64
import hashlib
import os

def generate_key_hash():
    """Generate Facebook key hash from Android keystore"""
    
    # Path to the debug keystore
    keystore_path = "android/app/login.jks"
    
    if not os.path.exists(keystore_path):
        print(f"Keystore not found at: {keystore_path}")
        return
    
    try:
        # Use keytool to extract certificate
        cmd = [
            "keytool", "-exportcert", "-alias", "test",
            "-keystore", keystore_path, "-storepass", "loginhanapp",
            "-keypass", "loginhanapp"
        ]
        
        # Run keytool command
        result = subprocess.run(cmd, capture_output=True)
        
        if result.returncode == 0:
            # Generate SHA1 hash
            sha1_hash = hashlib.sha1(result.stdout).digest()
            # Encode to base64
            key_hash = base64.b64encode(sha1_hash).decode('utf-8')
            
            print(f"Facebook Key Hash: {key_hash}")
            print("\nAdd this key hash to your Facebook app settings:")
            print("1. Go to https://developers.facebook.com/")
            print("2. Select your app")
            print("3. Go to Settings > Basic")
            print("4. Add the key hash to Android settings")
            
        else:
            print(f"Error running keytool: {result.stderr.decode()}")
            
    except FileNotFoundError:
        print("keytool not found. Make sure Java JDK is installed and in PATH")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate_key_hash()
