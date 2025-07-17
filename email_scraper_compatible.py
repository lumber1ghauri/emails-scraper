from collections import deque
import urllib.parse
import re
from bs4 import BeautifulSoup, Tag
import requests
import requests.exceptions as request_exception
import json
from flask import Flask, request, jsonify
from concurrent.futures import ThreadPoolExecutor
import threading
from typing import List, Dict, Any
import time
import asyncio
import httpx

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


# Enhanced email extraction to catch obfuscated emails and mailto links
import re

def extract_emails_advanced(response_text: str) -> set[str]:
    # Standard emails
    emails = set(re.findall(r'[a-z0-9.\-+_]+@[a-z0-9.\-+_]+\.[a-z]+', response_text, re.I))
    # Obfuscated emails
    obfuscated_patterns = [
        r'([a-z0-9.\-+_]+)\s*\[at\]\s*([a-z0-9.\-+_]+)\s*\[dot\]\s*([a-z]+)',
        r'([a-z0-9.\-+_]+)\s*\(at\)\s*([a-z0-9.\-+_]+)\s*\(dot\)\s*([a-z]+)',
        r'([a-z0-9.\-+_]+)\s*at\s*([a-z0-9.\-+_]+)\s*dot\s*([a-z]+)',
        r'([a-z0-9.\-+_]+)\s*@\s*([a-z0-9.\-+_]+)\s*\.\s*([a-z]+)'
    ]
    for pattern in obfuscated_patterns:
        for parts in re.findall(pattern, response_text, re.I):
            emails.add(f"{parts[0]}@{parts[1]}.{parts[2]}")
    # mailto links
    mailto_emails = set(re.findall(r'mailto:([a-z0-9.\-+_]+@[a-z0-9.\-+_]+\.[a-z]+)', response_text, re.I))
    emails.update(mailto_emails)
    return emails


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


# Expanded list of common subpages
COMMON_PATHS = [
    '', '/contact', '/contact-us', '/about', '/about-us', '/team', '/faculty', '/directory', '/staff'
]

async def fetch_page_async(client, url):
    try:
        resp = await client.get(url, timeout=3)
        resp.raise_for_status()
        return resp.text
    except httpx.HTTPStatusError as e:
        # Only print a summary for 403/404
        if e.response.status_code in (403, 404):
            print(f"    [SKIP] {url} returned {e.response.status_code}")
        else:
            print(f"    [ERROR] Failed to fetch: {url} ({e})")
        return None
    except Exception as e:
        print(f"    [ERROR] Failed to fetch: {url} ({e})")
        return None

async def extract_emails_from_known_pages(base_url, client):
    """
    Try to extract emails from common contact/about/faculty/etc. pages first.
    """
    for path in COMMON_PATHS:
        url = base_url.rstrip('/') + path
        print(f"  [KNOWN PAGE] {url}")
        html = await fetch_page_async(client, url)
        if html:
            try:
                soup = BeautifulSoup(html, 'html5lib')
            except Exception:
                soup = BeautifulSoup(html, 'html.parser')
            emails = extract_emails_advanced(html)
            if emails:
                print(f"    [EMAIL FOUND] {emails} on {url}")
                return emails
    return set()

async def async_scrape_website(start_url, max_count=5, client=None):
    """
    Asynchronously scrape a website, following links, to find emails.
    """
    urls_to_process = deque([start_url])
    scraped_urls = set()
    collected_emails = set()
    count = 0
    print(f"[START] Async scraping: {start_url}")
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
        html = await fetch_page_async(client, url)
        if not html:
            continue
        page_emails = extract_emails_advanced(html)
        if page_emails:
            print(f"    [EMAIL FOUND] {page_emails}")
        collected_emails.update(page_emails)
        if page_emails:
            print(f"[STOP] Found email(s) for {start_url}, stopping crawl.")
            return collected_emails
        try:
            soup = BeautifulSoup(html, 'html5lib')
        except Exception:
            soup = BeautifulSoup(html, 'html.parser')
        for anchor in soup.find_all('a'):
            if not isinstance(anchor, Tag):
                continue
            link = anchor.get('href')
            if not link or not isinstance(link, str):
                continue
            if any(link.lower().endswith(ext) for ext in ['.pdf', '.jpg', '.jpeg', '.png', '.gif', '.zip', '.rar', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx']):
                continue
            normalized_link = normalize_link(link, base_url, page_path)
            if normalized_link not in urls_to_process and normalized_link not in scraped_urls:
                urls_to_process.append(normalized_link)
    print(f"[END] Done async scraping: {start_url}")
    return collected_emails

async def process_single_website_async(website_data, max_count=5, client=None):
    name = website_data.get('Name', 'Unknown')
    website = website_data.get('Website', '')
    existing_email = website_data.get('Email')
    description = website_data.get('Description', '')
    if existing_email:
        print(f"[SKIP] {website} already has email: {existing_email}")
        return {
            'Name': name,
            'Website': website,
            'Email': existing_email,
            'Description': description,
            'Status': 'Already exists'
        }
    try:
        base_url = get_base_url(website)
        # Try known pages first
        emails = await extract_emails_from_known_pages(base_url, client)
        if emails:
            first_email = list(emails)[0]
            return {
                'Name': name,
                'Website': website,
                'Email': first_email,
                'Description': description,
                'Status': 'Found (known page)'
            }
        # Fallback to async crawl
        emails = await async_scrape_website(website, max_count=max_count, client=client)
        if emails:
            first_email = list(emails)[0]
            return {
                'Name': name,
                'Website': website,
                'Email': first_email,
                'Description': description,
                'Status': 'Found (crawl)'
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

async def process_websites_async(websites_data, max_count=5, max_workers=10):
    results = []
    sem = asyncio.Semaphore(max_workers)
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    async with httpx.AsyncClient(headers=headers, follow_redirects=True) as client:
        async def sem_task(website_data):
            async with sem:
                return await process_single_website_async(website_data, max_count, client)
        tasks = [sem_task(w) for w in websites_data]
        results = await asyncio.gather(*tasks)
    return results


@app.route('/scrape-emails', methods=['POST'])
async def scrape_emails_endpoint():
    print("request received from website (async)")
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
        max_workers = data.get('max_workers', 10)
        max_count = data.get('max_count', 5)
        
        if not isinstance(websites, list):
            return jsonify({'error': 'Websites must be a list'}), 400
        
        start_time = time.time()
        
        results = await process_websites_async(websites, max_count, max_workers)
        
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
    app.run(host='0.0.0.0', port=5000, debug=True)
    # try:
    #     from waitress import serve
    #     print("Starting with Waitress WSGI server on http://0.0.0.0:5000 ...")
    #     serve(app, host='0.0.0.0', port=5000)
    # except ImportError:
    #     print("Waitress is not installed. Please install it with 'pip install waitress'. Running with Flask development server (not recommended for production).")
    #     app.run(host='0.0.0.0', port=5000, debug=True)
