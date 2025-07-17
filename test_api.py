#!/usr/bin/env python3
import requests
import json

def test_api():
    """Test the email scraper API"""
    
    # Test data
    test_data = {
    "websites": [
        {"Name": "IGE Overseas", "Website": "https://igeoverseas.com/", "Email": None, "Description": "Top study abroad consultants in Lahore."},
        {"Name": "Universities Page", "Website": "https://universitiespage.com/", "Email": None, "Description": "Education consultant in Lahore."},
        {"Name": "Pakistan Embassy Sweden", "Website": "https://www.pakistanembassy.se/", "Email": None, "Description": "Embassy of Pakistan in Sweden."},
        {"Name": "HEC Pakistan", "Website": "https://www.hec.gov.pk/", "Email": None, "Description": "Higher Education Commission of Pakistan."},
        {"Name": "LUMS", "Website": "https://www.lums.edu.pk/", "Email": None, "Description": "Lahore University of Management Sciences."},
        {"Name": "NUST", "Website": "https://www.nust.edu.pk/", "Email": None, "Description": "National University of Sciences and Technology."},
        {"Name": "Pakistan In The World", "Website": "https://www.pakistanintheworld.pk/", "Email": None, "Description": "News and analysis from Pakistan."},
        {"Name": "Pakistan Government", "Website": "https://www.pakistan.gov.pk/", "Email": None, "Description": "Official portal of the Government of Pakistan."},
        {"Name": "Pakistan Embassy", "Website": "https://www.pakistan-embassy.com/", "Email": None, "Description": "Pakistan Embassy information."},
        {"Name": "Pakistan Consulate NY", "Website": "https://www.pakistanconsulateny.org/", "Email": None, "Description": "Consulate General of Pakistan, New York."},
        {"Name": "UET Lahore", "Website": "https://www.uet.edu.pk/", "Email": None, "Description": "University of Engineering and Technology, Lahore."},
        {"Name": "IBA Karachi", "Website": "https://www.iba.edu.pk/", "Email": None, "Description": "Institute of Business Administration, Karachi."},
        {"Name": "COMSATS", "Website": "https://www.comsats.edu.pk/", "Email": None, "Description": "COMSATS University Islamabad."},
        {"Name": "FAST NUCES", "Website": "https://www.nu.edu.pk/", "Email": None, "Description": "National University of Computer and Emerging Sciences."},
        {"Name": "Punjab University", "Website": "http://pu.edu.pk/", "Email": None, "Description": "University of the Punjab, Lahore."},
        {"Name": "Dawn News", "Website": "https://www.dawn.com/", "Email": None, "Description": "Leading Pakistani news site."},
        {"Name": "Express Tribune", "Website": "https://tribune.com.pk/", "Email": None, "Description": "Pakistani news and media site."},
        {"Name": "Geo News", "Website": "https://www.geo.tv/", "Email": None, "Description": "Pakistani news channel."},
        {"Name": "ARY News", "Website": "https://arynews.tv/", "Email": None, "Description": "Pakistani news channel."},
        {"Name": "PTCL", "Website": "https://www.ptcl.com.pk/", "Email": None, "Description": "Pakistan Telecommunication Company Limited."}
    ],
    "concurrent": True,
    "max_workers": 20,
    "max_count": 10
}
    try:
        # Make request to API
        response = requests.post(
            'http://localhost:5000/scrape-emails',
            json=test_data,
            timeout=60
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
