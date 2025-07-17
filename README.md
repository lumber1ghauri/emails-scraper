# Email Scraper API

A Python Flask API for scraping email addresses from websites. Built for Python 3.13 compatibility.

## Features

- **Email Extraction**: Scrapes websites and extracts email addresses
- **Concurrent Processing**: Processes multiple websites simultaneously
- **RESTful API**: Simple HTTP endpoints for integration
- **Python 3.13 Compatible**: Works with the latest Python version
- **Error Handling**: Robust error handling and logging

## Quick Start

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the server:
```bash
python email_scraper_compatible.py
```

The API will be available at `http://localhost:5000`

## API Endpoints

### POST /scrape-emails

Scrapes emails from multiple websites concurrently.

**Request Body:**
```json
{
  "websites": [
    {
      "Name": "IGE Overseas",
      "Website": "https://igeoverseas.com/",
      "Email": null,
      "Description": "Top study abroad consultants in Lahore."
    },
    {
      "Name": "Universities Page",
      "Website": "https://universitiespage.com/",
      "Email": null,
      "Description": "Best study abroad education consultant in Lahore Pakistan."
    }
  ],
  "concurrent": true,
  "max_workers": 10
}
```

**Response:**
```json
{
  "results": [
    {
      "Name": "IGE Overseas",
      "Website": "https://igeoverseas.com/",
      "Email": "info@igeoverseas.com",
      "Description": "Top study abroad consultants in Lahore.",
      "Status": "Found"
    },
    {
      "Name": "Universities Page",
      "Website": "https://universitiespage.com/",
      "Email": null,
      "Description": "Best study abroad education consultant in Lahore Pakistan.",
      "Status": "Not found"
    }
  ],
  "total_websites": 2,
  "processing_time_seconds": 5.23,
  "found_emails": 1,
  "errors": 0
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "email-scraper"
}
```

## Usage Examples

### Using curl

```bash
curl -X POST http://localhost:5000/scrape-emails \
  -H "Content-Type: application/json" \
  -d '{
    "websites": [
      {
        "Name": "Test Company",
        "Website": "https://example.com",
        "Email": null,
        "Description": "Test description"
      }
    ],
    "concurrent": true,
    "max_workers": 5
  }'
```

### Using Python requests

```python
import requests
import json

# Your website data
websites_data = [
    {
        "Name": "IGE Overseas",
        "Website": "https://igeoverseas.com/",
        "Email": null,
        "Description": "Top study abroad consultants in Lahore."
    },
    {
        "Name": "Universities Page",
        "Website": "https://universitiespage.com/",
        "Email": null,
        "Description": "Best study abroad education consultant in Lahore Pakistan."
    }
]

# Make API request
response = requests.post(
    'http://localhost:5000/scrape-emails',
    json={
        'websites': websites_data,
        'concurrent': True,
        'max_workers': 10
    }
)

# Process results
if response.status_code == 200:
    results = response.json()
    print(f"Processed {results['total_websites']} websites in {results['processing_time_seconds']} seconds")
    print(f"Found {results['found_emails']} emails")
    
    for result in results['results']:
        if result['Email']:
            print(f"✓ {result['Name']}: {result['Email']}")
        else:
            print(f"✗ {result['Name']}: No email found")
else:
    print(f"Error: {response.text}")
```

### Using n8n

1. Add an **HTTP Request** node
2. Set method to `POST`
3. Set URL to `http://localhost:5000/scrape-emails`
4. Set Headers: `Content-Type: application/json`
5. Set Body to your JSON data with websites

## Configuration Options

- **concurrent**: Boolean, enables concurrent processing (default: true)
- **max_workers**: Integer, maximum number of concurrent threads (default: 10)
- **timeout**: Request timeout in seconds (default: 10)

## Performance

- **Concurrent Processing**: Uses ThreadPoolExecutor for parallel website processing
- **Sequential Processing**: Also supports sequential processing for simpler use cases
- **Timeout Management**: Configurable timeouts to prevent hanging requests
- **Error Recovery**: Continues processing even if some websites fail

## Error Handling

The API handles various error scenarios:
- Network timeouts
- Invalid URLs
- HTTP errors
- Parsing errors
- Missing data

All errors are logged and included in the response with appropriate status messages.

## Security Considerations

- The API runs on `0.0.0.0:5000` by default (accessible from any IP)
- Consider using a reverse proxy (nginx) for production
- Add authentication if needed
- Rate limiting may be required for high-volume usage

## Production Deployment

For production use:

1. Use a WSGI server like Gunicorn:
```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 email_scraper_compatible:app
```

2. Add environment variables for configuration
3. Use a reverse proxy (nginx)
4. Add monitoring and logging

## Dependencies

- **Flask 3.0.0**: Web framework
- **Requests 2.31.0**: HTTP library
- **BeautifulSoup4 4.12.2**: HTML parsing
- **html5lib 1.1**: HTML5 parser
- **httpx 0.25.0**: Modern HTTP client

## Testing

Run the test script to verify the API:
```bash
python test_api.py
```
