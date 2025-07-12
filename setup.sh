#!/bin/bash

echo "🚀 Email Scraper Setup Script"
echo "=============================="

# Check if running as root (needed for package installation)
if [[ $EUID -eq 0 ]]; then
   echo "❌ Please don't run this script as root"
   exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Python 3.11
install_python311() {
    echo "📦 Installing Python 3.11..."
    
    if command_exists python3.11; then
        echo "✅ Python 3.11 is already installed"
        return 0
    fi
    
    # Try to install Python 3.11
    if command_exists pacman; then
        echo "📥 Installing Python 3.11 via pacman..."
        sudo pacman -S --noconfirm python311
    elif command_exists apt; then
        echo "📥 Installing Python 3.11 via apt..."
        sudo apt update
        sudo apt install -y python3.11 python3.11-venv python3.11-dev
    elif command_exists yum; then
        echo "📥 Installing Python 3.11 via yum..."
        sudo yum install -y python3.11 python3.11-devel
    elif command_exists dnf; then
        echo "📥 Installing Python 3.11 via dnf..."
        sudo dnf install -y python3.11 python3.11-devel
    else
        echo "❌ Could not install Python 3.11 automatically"
        echo "Please install Python 3.11 manually and run this script again"
        exit 1
    fi
    
    if ! command_exists python3.11; then
        echo "❌ Failed to install Python 3.11"
        exit 1
    fi
    
    echo "✅ Python 3.11 installed successfully"
}

# Function to create virtual environment
create_venv() {
    echo "🔧 Creating virtual environment..."
    
    # Remove existing venv if it exists
    if [ -d "venv" ]; then
        echo "🗑️  Removing existing virtual environment..."
        rm -rf venv
    fi
    
    # Create new virtual environment with Python 3.11
    python3.11 -m venv venv
    
    if [ ! -d "venv" ]; then
        echo "❌ Failed to create virtual environment"
        exit 1
    fi
    
    echo "✅ Virtual environment created successfully"
}

# Function to activate venv and install dependencies
install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    # Install dependencies
    pip install flask==2.3.3
    pip install requests==2.31.0
    pip install beautifulsoup4==4.12.2
    pip install lxml==4.9.3
    pip install aiohttp==3.8.6
    
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
import lxml
import aiohttp
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

echo "🚀 Starting Email Scraper API..."

# Activate virtual environment
source venv/bin/activate

# Run the API
python email_scraper.py
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
pkill -f "python email_scraper.py"

echo "✅ API stopped"
EOF

    chmod +x stop.sh
    echo "✅ Stop script created: stop.sh"
}

# Main execution
main() {
    echo "🔍 Checking system requirements..."
    
    # Install Python 3.11
    install_python311
    
    # Create virtual environment
    create_venv
    
    # Install dependencies
    install_dependencies
    
    # Test installation
    test_installation
    
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
}

# Run main function
main 