#!/bin/bash

echo "🛑 Stopping Email Scraper API..."

# Find and kill the process
pkill -f "python email_scraper_compatible.py"

echo "✅ API stopped"
