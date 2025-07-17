from collections import deque
import urllib.parse
import re
from bs4 import BeautifulSoup
import requests
import requests.exceptions as request_exception
import json
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


def scrape_website(start_url: str, max_count: int = 5) -> set[str]:
    """
    Scrapes a website starting from the given URL, follows links, and collects email addresses.
    Stops after finding the first email.

    :param start_url: The initial URL to start scraping.
    :param max_count: The maximum number of pages to scrape. Defaults to 5.
    :return: A set of email addresses found during the scraping process.
    """

    urls_to_process = deque([start_url])
    scraped_urls = set()
    collected_emails = set()
    count = 0

    print(f"[START] Scraping: {start_url}")

    while urls_to_process:
        count += 1
        if count > max_count:
            print(f"[LIMIT] Reached max_count ({max_count}) for {start_url}")
            break

        url = urls_to_process.popleft()
        if url in scraped_urls:
            continue

        scraped_urls.add(url)
        base_url = get_base_url(url)
        page_path = get_page_path(url)

        print(f"  [PAGE {count}] {url}")

        try:
            response = requests.get(url, timeout=3)
            response.raise_for_status()
        except (request_exception.RequestException, request_exception.MissingSchema, request_exception.ConnectionError):
            print(f"    [ERROR] Failed to fetch: {url}")
            continue

        # Extract emails from current page
        page_emails = extract_emails(response.text)
        if page_emails:
            print(f"    [EMAIL FOUND] {page_emails}")
        collected_emails.update(page_emails)
        
        # If we found any emails on this page, stop and return
        if page_emails:
            print(f"[STOP] Found email(s) for {start_url}, stopping crawl.")
            return collected_emails

        # Use html5lib parser instead of lxml
        soup = BeautifulSoup(response.text, 'html5lib')

        for anchor in soup.find_all('a'):
            link = anchor.get('href', '')
            # Skip non-HTML links (pdf, jpg, png, etc.)
            if any(link.lower().endswith(ext) for ext in ['.pdf', '.jpg', '.jpeg', '.png', '.gif', '.zip', '.rar', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx']):
                continue
            normalized_link = normalize_link(link, base_url, page_path)
            if normalized_link not in urls_to_process and normalized_link not in scraped_urls:
                urls_to_process.append(normalized_link)

    print(f"[END] Done scraping: {start_url}")
    return collected_emails


def process_single_website(website_data: Dict[str, Any], max_count: int = 5) -> Dict[str, Any]:
    """
    Process a single website and return results.

    :param website_data: Dictionary containing website information
    :param max_count: Maximum number of pages to scrape per website
    :return: Dictionary with updated email information
    """
    name = website_data.get('Name', 'Unknown')
    website = website_data.get('Website', '')
    existing_email = website_data.get('Email')
    description = website_data.get('Description', '')
    
    # If email already exists, skip scraping
    if existing_email:
        print(f"[SKIP] {website} already has email: {existing_email}")
        return {
            'Name': name,
            'Website': website,
            'Email': existing_email,
            'Description': description,
            'Status': 'Already exists'
        }
    
    # Scrape for emails
    try:
        found_emails = scrape_website(website, max_count=max_count)
        if found_emails:
            # Take the first email found
            first_email = list(found_emails)[0]
            return {
                'Name': name,
                'Website': website,
                'Email': first_email,
                'Description': description,
                'Status': 'Found'
            }
        else:
            return {
                'Name': name,
                'Website': website,
                'Email': None,
                'Description': description,
                'Status': 'Not found'
            }
    except Exception as e:
        print(f"[ERROR] Exception while scraping {website}: {e}")
        return {
            'Name': name,
            'Website': website,
            'Email': None,
            'Description': description,
            'Status': f'Error: {str(e)}'
        }


def process_websites_concurrent(websites_data: List[Dict[str, Any]], max_workers: int = 10, max_count: int = 5) -> List[Dict[str, Any]]:
    """
    Process multiple websites concurrently using ThreadPoolExecutor.

    :param websites_data: List of dictionaries containing website information
    :param max_workers: Maximum number of concurrent threads
    :param max_count: Maximum number of pages to scrape per website
    :return: List of dictionaries with updated email information
    """
    results = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_website = {
            executor.submit(process_single_website, website_data, max_count): website_data 
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
                print(f"[ERROR] Exception in thread for {website}: {e}")
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
    print("request received from website")
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
        max_count = data.get('max_count', 5)  # Allow override from API input
        
        if not isinstance(websites, list):
            return jsonify({'error': 'Websites must be a list'}), 400
        
        start_time = time.time()
        
        if use_concurrent:
            # Use ThreadPoolExecutor for concurrent processing
            results = process_websites_concurrent(websites, max_workers, max_count)
        else:
            # Process websites sequentially
            results = []
            for website_data in websites:
                result = process_single_website(website_data, max_count)
                results.append(result)
        
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
        print(f"[ERROR] Internal server error: {e}")
        return jsonify({'error': f'Internal server error: {str(e)}'}), 500


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'service': 'email-scraper'})


if __name__ == '__main__':
    try:
        from waitress import serve
        print("Starting with Waitress WSGI server on http://0.0.0.0:5000 ...")
        serve(app, host='0.0.0.0', port=5000)
    except ImportError:
        print("Waitress is not installed. Please install it with 'pip install waitress'. Running with Flask development server (not recommended for production).")
        app.run(host='0.0.0.0', port=5000, debug=True)
