#!/bin/bash

echo "🚀 Email Scraper Setup Script (Fixed for Python 3.13)"
echo "====================================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Please don't run this script as root"
   exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create virtual environment with current Python
create_venv() {
    echo "🔧 Creating virtual environment..."
    
    # Remove existing venv if it exists
    if [ -d "venv" ]; then
        echo "🗑️  Removing existing virtual environment..."
        rm -rf venv
    fi
    
    # Create new virtual environment with current Python
    python -m venv venv
    
    if [ ! -d "venv" ]; then
        echo "❌ Failed to create virtual environment"
        exit 1
    fi
    
    echo "✅ Virtual environment created successfully"
}

# Function to install dependencies with compatible versions
install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    # Install dependencies with compatible versions for Python 3.13
    echo "Installing Flask..."
    pip install flask
    
    echo "Installing requests..."
    pip install requests
    
    echo "Installing beautifulsoup4..."
    pip install beautifulsoup4
    
    echo "Installing html5lib (alternative to lxml)..."
    pip install html5lib
    
    echo "Installing httpx (alternative to aiohttp)..."
    pip install httpx
    
    echo "Installing asyncio..."
    # asyncio is built into Python 3.13
    
    echo "✅ Dependencies installed successfully"
}

# Function to test the installation
test_installation() {
    echo "🧪 Testing installation..."
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Test Python import
    python3 -c "
import flask
import requests
import bs4
import html5lib
import httpx
import asyncio
print('✅ All imports successful!')
"
    
    if [ $? -eq 0 ]; then
        echo "✅ Installation test passed!"
    else
        echo "❌ Installation test failed!"
        exit 1
    fi
}

# Function to create a modified email scraper that works with Python 3.13
create_compatible_scraper() {
    echo "📝 Creating compatible email scraper..."
    
    cat > email_scraper_compatible.py << 'EOF'
from collections import deque
import urllib.parse
import re
from bs4 import BeautifulSoup
import requests
import requests.exceptions as request_exception
import json
import asyncio
import httpx
from flask import Flask, request, jsonify
from concurrent.futures import ThreadPoolExecutor
import threading
from typing import List, Dict, Any
import time


app = Flask(__name__)


def get_base_url(url: str) -> str:
    """
    Extracts the base URL (scheme and netloc) from a given URL.

    :param url: The full URL from which to extract the base.
    :return: The base URL in the form 'scheme://netloc'.
    """

    parts = urllib.parse.urlsplit(url)
    return '{0.scheme}://{0.netloc}'.format(parts)


def get_page_path(url: str) -> str:
    """
    Extracts the page path from the given URL, used to normalize relative links.

    :param url: The full URL from which to extract the page path.
    :return: The page path (URL up to the last '/').
    """

    parts = urllib.parse.urlsplit(url)
    return url[:url.rfind('/') + 1] if '/' in parts.path else url


def extract_emails(response_text: str) -> set[str]:
    """
    Extracts all email addresses from the provided HTML text.

    :param response_text: The raw HTML content of a webpage.
    :return: A set of email addresses found within the content.
    """

    email_pattern = r'[a-z0-9\.\-+]+@[a-z0-9\.\-+]+\.[a-z]+'
    return set(re.findall(email_pattern, response_text, re.I))


def normalize_link(link: str, base_url: str, page_path: str) -> str:
    """
    Normalizes relative links into absolute URLs.

    :param link: The link to normalize (could be relative or absolute).
    :param base_url: The base URL for relative links starting with '/'.
    :param page_path: The page path for relative links not starting with '/'.
    :return: The normalized link as an absolute URL.
    """

    if link.startswith('/'):
        return base_url + link
    elif not link.startswith('http'):
        return page_path + link
    return link


def scrape_website(start_url: str, max_count: int = 100) -> set[str]:
    """
    Scrapes a website starting from the given URL, follows links, and collects email addresses.
    Stops after finding the first email.

    :param start_url: The initial URL to start scraping.
    :param max_count: The maximum number of pages to scrape. Defaults to 100.
    :return: A set of email addresses found during the scraping process.
    """

    urls_to_process = deque([start_url])
    scraped_urls = set()
    collected_emails = set()
    count = 0

    while urls_to_process:
        count += 1
        if count > max_count:
            break

        url = urls_to_process.popleft()
        if url in scraped_urls:
            continue

        scraped_urls.add(url)
        base_url = get_base_url(url)
        page_path = get_page_path(url)

        print(f'[{count}] Processing {url}')

        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
        except (request_exception.RequestException, request_exception.MissingSchema, request_exception.ConnectionError):
            print('There was a request error')
            continue

        # Extract emails from current page
        page_emails = extract_emails(response.text)
        collected_emails.update(page_emails)
        
        # If we found any emails on this page, stop and return
        if page_emails:
            print(f'[+] Found {len(page_emails)} email(s) on {url}')
            return collected_emails

        # Use html5lib parser instead of lxml
        soup = BeautifulSoup(response.text, 'html5lib')

        for anchor in soup.find_all('a'):
            link = anchor.get('href', '')
            normalized_link = normalize_link(link, base_url, page_path)
            if normalized_link not in urls_to_process and normalized_link not in scraped_urls:
                urls_to_process.append(normalized_link)

    return collected_emails


async def scrape_website_async(client: httpx.AsyncClient, start_url: str, max_count: int = 100) -> set[str]:
    """
    Asynchronous version of website scraping using httpx.

    :param client: httpx client for making requests
    :param start_url: The initial URL to start scraping.
    :param max_count: The maximum number of pages to scrape. Defaults to 100.
    :return: A set of email addresses found during the scraping process.
    """

    urls_to_process = deque([start_url])
    scraped_urls = set()
    collected_emails = set()
    count = 0

    while urls_to_process:
        count += 1
        if count > max_count:
            break

        url = urls_to_process.popleft()
        if url in scraped_urls:
            continue

        scraped_urls.add(url)
        base_url = get_base_url(url)
        page_path = get_page_path(url)

        print(f'[{count}] Processing {url}')

        try:
            response = await client.get(url, timeout=10.0)
            if response.status_code == 200:
                html_content = response.text
                
                # Extract emails from current page
                page_emails = extract_emails(html_content)
                collected_emails.update(page_emails)
                
                # If we found any emails on this page, stop and return
                if page_emails:
                    print(f'[+] Found {len(page_emails)} email(s) on {url}')
                    return collected_emails

                # Use html5lib parser instead of lxml
                soup = BeautifulSoup(html_content, 'html5lib')

                for anchor in soup.find_all('a'):
                    link = anchor.get('href', '')
                    normalized_link = normalize_link(link, base_url, page_path)
                    if normalized_link not in urls_to_process and normalized_link not in scraped_urls:
                        urls_to_process.append(normalized_link)
            else:
                print(f'HTTP {response.status_code} for {url}')
        except Exception as e:
            print(f'Error processing {url}: {str(e)}')
            continue

    return collected_emails


def process_single_website(website_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Process a single website and return results.

    :param website_data: Dictionary containing website information
    :return: Dictionary with updated email information
    """
    name = website_data.get('Name', 'Unknown')
    website = website_data.get('Website', '')
    existing_email = website_data.get('Email')
    description = website_data.get('Description', '')
    
    print(f'Processing: {name} - {website}')
    
    # If email already exists, skip scraping
    if existing_email:
        print(f'[!] Email already exists: {existing_email}')
        return {
            'Name': name,
            'Website': website,
            'Email': existing_email,
            'Description': description,
            'Status': 'Already exists'
        }
    
    # Scrape for emails
    try:
        found_emails = scrape_website(website)
        if found_emails:
            # Take the first email found
            first_email = list(found_emails)[0]
            print(f'[+] Found email: {first_email}')
            return {
                'Name': name,
                'Website': website,
                'Email': first_email,
                'Description': description,
                'Status': 'Found'
            }
        else:
            print(f'[-] No emails found')
            return {
                'Name': name,
                'Website': website,
                'Email': None,
                'Description': description,
                'Status': 'Not found'
            }
    except Exception as e:
        print(f'[!] Error processing {website}: {str(e)}')
        return {
            'Name': name,
            'Website': website,
            'Email': None,
            'Description': description,
            'Status': f'Error: {str(e)}'
        }


async def process_websites_async(websites_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Process multiple websites concurrently using asyncio and httpx.

    :param websites_data: List of dictionaries containing website information
    :return: List of dictionaries with updated email information
    """
    results = []
    
    # Create httpx client for concurrent requests
    async with httpx.AsyncClient() as client:
        tasks = []
        
        for website_data in websites_data:
            name = website_data.get('Name', 'Unknown')
            website = website_data.get('Website', '')
            existing_email = website_data.get('Email')
            description = website_data.get('Description', '')
            
            print(f'Adding task for: {name} - {website}')
            
            # If email already exists, skip scraping
            if existing_email:
                print(f'[!] Email already exists: {existing_email}')
                results.append({
                    'Name': name,
                    'Website': website,
                    'Email': existing_email,
                    'Description': description,
                    'Status': 'Already exists'
                })
                continue
            
            # Create async task for scraping
            task = asyncio.create_task(scrape_website_async(client, website))
            tasks.append((website_data, task))
        
        # Wait for all tasks to complete
        for website_data, task in tasks:
            try:
                found_emails = await task
                name = website_data.get('Name', 'Unknown')
                website = website_data.get('Website', '')
                description = website_data.get('Description', '')
                
                if found_emails:
                    first_email = list(found_emails)[0]
                    print(f'[+] Found email: {first_email} for {name}')
                    results.append({
                        'Name': name,
                        'Website': website,
                        'Email': first_email,
                        'Description': description,
                        'Status': 'Found'
                    })
                else:
                    print(f'[-] No emails found for {name}')
                    results.append({
                        'Name': name,
                        'Website': website,
                        'Email': None,
                        'Description': description,
                        'Status': 'Not found'
                    })
            except Exception as e:
                name = website_data.get('Name', 'Unknown')
                website = website_data.get('Website', '')
                description = website_data.get('Description', '')
                print(f'[!] Error processing {website}: {str(e)}')
                results.append({
                    'Name': name,
                    'Website': website,
                    'Email': None,
                    'Description': description,
                    'Status': f'Error: {str(e)}'
                })
    
    return results


def process_websites_concurrent(websites_data: List[Dict[str, Any]], max_workers: int = 10) -> List[Dict[str, Any]]:
    """
    Process multiple websites concurrently using ThreadPoolExecutor.

    :param websites_data: List of dictionaries containing website information
    :param max_workers: Maximum number of concurrent threads
    :return: List of dictionaries with updated email information
    """
    results = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_website = {
            executor.submit(process_single_website, website_data): website_data 
            for website_data in websites_data
        }
        
        # Collect results as they complete
        for future in future_to_website:
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                website_data = future_to_website[future]
                name = website_data.get('Name', 'Unknown')
                website = website_data.get('Website', '')
                description = website_data.get('Description', '')
                
                print(f'[!] Error processing {website}: {str(e)}')
                results.append({
                    'Name': name,
                    'Website': website,
                    'Email': None,
                    'Description': description,
                    'Status': f'Error: {str(e)}'
                })
    
    return results


@app.route('/scrape-emails', methods=['POST'])
def scrape_emails_endpoint():
    """
    API endpoint to scrape emails from multiple websites.
    
    Expected JSON input:
    {
        "websites": [
            {
                "Name": "Company Name",
                "Website": "https://example.com",
                "Email": null,
                "Description": "Company description"
            }
        ],
        "concurrent": true,
        "max_workers": 10
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'websites' not in data:
            return jsonify({'error': 'Missing websites data'}), 400
        
        websites = data['websites']
        use_concurrent = data.get('concurrent', True)
        max_workers = data.get('max_workers', 10)
        
        if not isinstance(websites, list):
            return jsonify({'error': 'Websites must be a list'}), 400
        
        print(f'Processing {len(websites)} websites...')
        start_time = time.time()
        
        if use_concurrent:
            # Use ThreadPoolExecutor for concurrent processing
            results = process_websites_concurrent(websites, max_workers)
        else:
            # Use asyncio for async processing (alternative)
            results = asyncio.run(process_websites_async(websites))
        
        end_time = time.time()
        processing_time = end_time - start_time
        
        response_data = {
            'results': results,
            'total_websites': len(websites),
            'processing_time_seconds': round(processing_time, 2),
            'found_emails': len([r for r in results if r.get('Email')]),
            'errors': len([r for r in results if 'Error' in r.get('Status', '')])
        }
        
        return jsonify(response_data)
        
    except Exception as e:
        return jsonify({'error': f'Internal server error: {str(e)}'}), 500


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'service': 'email-scraper'})


if __name__ == '__main__':
    print("Starting Email Scraper API (Python 3.13 Compatible)...")
    print("Available endpoints:")
    print("- POST /scrape-emails - Scrape emails from multiple websites")
    print("- GET /health - Health check")
    print("\nExample usage:")
    print('curl -X POST http://localhost:5000/scrape-emails \\')
    print('  -H "Content-Type: application/json" \\')
    print('  -d \'{"websites": [{"Name": "Test", "Website": "https://example.com", "Email": null, "Description": "Test site"}], "concurrent": true, "max_workers": 5}\'')
    
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF

    echo "✅ Compatible email scraper created: email_scraper_compatible.py"
}

# Function to create a simple test script
create_test_script() {
    echo "📝 Creating test script..."
    
    cat > test_api.py << 'EOF'
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
EOF

    chmod +x test_api.py
    echo "✅ Test script created: test_api.py"
}

# Function to create a run script
create_run_script() {
    echo "📝 Creating run script..."
    
    cat > run.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Email Scraper API (Python 3.13 Compatible)..."

# Activate virtual environment
source venv/bin/activate

# Run the compatible API
python email_scraper_compatible.py
EOF

    chmod +x run.sh
    echo "✅ Run script created: run.sh"
}

# Function to create a stop script
create_stop_script() {
    echo "📝 Creating stop script..."
    
    cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Email Scraper API..."

# Find and kill the process
pkill -f "python email_scraper_compatible.py"

echo "✅ API stopped"
EOF

    chmod +x stop.sh
    echo "✅ Stop script created: stop.sh"
}

# Main execution
main() {
    echo "🔍 Checking system requirements..."
    
    # Create virtual environment
    create_venv
    
    # Install dependencies
    install_dependencies
    
    # Test installation
    test_installation
    
    # Create compatible scraper
    create_compatible_scraper
    
    # Create helper scripts
    create_test_script
    create_run_script
    create_stop_script
    
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Start the API: ./run.sh"
    echo "2. Test the API: ./test_api.py"
    echo "3. Stop the API: ./stop.sh"
    echo ""
    echo "🌐 API will be available at: http://localhost:5000"
    echo "📖 API documentation:"
    echo "   - POST /scrape-emails - Scrape emails from websites"
    echo "   - GET /health - Health check"
    echo ""
    echo "💡 Example usage:"
    echo 'curl -X POST http://localhost:5000/scrape-emails \'
    echo '  -H "Content-Type: application/json" \'
    echo '  -d '"'"'{"websites": [{"Name": "Test", "Website": "https://example.com", "Email": null, "Description": "Test"}], "concurrent": true, "max_workers": 5}'"'"''
    echo ""
    echo "🔧 Changes made for Python 3.13 compatibility:"
    echo "   - Replaced lxml with html5lib parser"
    echo "   - Replaced aiohttp with httpx"
    echo "   - Used built-in asyncio"
}

# Run main function
main 