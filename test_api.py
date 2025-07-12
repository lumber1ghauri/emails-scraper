#!/usr/bin/env python3
import requests
import json

def test_api():
    """Test the email scraper API"""
    
    # Test data
    test_data = {
        "websites": [
            {
                "Name": "Test Company",
                "Website": "https://httpbin.org/html",
                "Email": None,
                "Description": "Test website"
            }
        ],
        "concurrent": True,
        "max_workers": 1
    }
    
    try:
        # Make request to API
        response = requests.post(
            'http://localhost:5000/scrape-emails',
            json=test_data,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ API test successful!")
            print(f"Response: {json.dumps(result, indent=2)}")
        else:
            print(f"❌ API test failed with status {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Could not connect to API. Make sure the server is running.")
    except Exception as e:
        print(f"❌ Test failed: {str(e)}")

if __name__ == "__main__":
    test_api()
