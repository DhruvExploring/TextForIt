#!/bin/bash

# ================================================
# TextForIt — EC2 Production Script
# Replaces local run.sh for EC2 Ubuntu 22.04
# ================================================

set -e

echo "================================================="
echo "   TextForIt EC2 Setup Starting..."
echo "================================================="

# ── Step 1: System Update ──────────────────────────
echo ""
echo "[1/6] Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-venv python3-pip git curl nginx

# Install Node.js 20 (works on x86 and ARM64)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi
echo "Node version: $(node -v)"

# ── Step 2: Setup Backend ──────────────────────────
echo ""
echo "[2/6] Setting up Backend..."
cd backend

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi

echo "Activating virtual environment..."
source .venv/bin/activate

echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

cd ..

# ── Step 3: Setup Frontend Build ───────────────────
echo ""
echo "[3/6] Building React Frontend..."
cd frontend

if [ ! -d "node_modules" ]; then
    echo "Installing Node dependencies..."
    npm install
fi

echo "Building for production..."
npm run build

cd ..

# ── Step 4: Setup systemd Service ─────────────────
echo ""
echo "[4/6] Creating systemd service..."

# Get current directory for absolute paths
PROJECT_DIR=$(pwd)

sudo bash -c "cat > /etc/systemd/system/textforit.service << EOF
[Unit]
Description=TextForIt FastAPI Backend
After=network.target

[Service]
User=ubuntu
WorkingDirectory=${PROJECT_DIR}/backend
Environment=\"PATH=${PROJECT_DIR}/backend/.venv/bin\"
EnvironmentFile=${PROJECT_DIR}/backend/.env
ExecStart=${PROJECT_DIR}/backend/.venv/bin/uvicorn Server:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable textforit
sudo systemctl start textforit

# ── Step 5: Setup Nginx ────────────────────────────
echo ""
echo "[5/6] Configuring Nginx..."

sudo bash -c "cat > /etc/nginx/sites-available/textforit << EOF
server {
    listen 80;
    server_name _;

    # Serve React frontend static files
    location / {
        root ${PROJECT_DIR}/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # Proxy API requests to FastAPI backend
    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;
    }
}
EOF"

sudo ln -sf /etc/nginx/sites-available/textforit /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

# ── Step 6: Check .env ─────────────────────────────
echo ""
echo "[6/6] Checking environment variables..."

if [ ! -f "backend/.env" ]; then
    echo "WARNING: No .env file found! Creating a template..."
    cat > backend/.env << EOF
GOOGLE_API_KEY=your_gemini_api_key_here
EOF
    echo "  --> Edit it now: nano backend/.env"
    echo "  --> Then restart: sudo systemctl restart textforit"
else
    echo "OK: .env file found"
    sudo systemctl restart textforit
fi

# ── Done ───────────────────────────────────────────
echo ""
echo "================================================="
echo "   TextForIt is Live!"
echo "================================================="
echo ""
echo "  App URL:      http://$(curl -s ifconfig.me)"
echo "  Backend API:  http://$(curl -s ifconfig.me)/api"
echo ""
echo "Useful commands:"
echo "  Check status:   sudo systemctl status textforit"
echo "  Live logs:      sudo journalctl -u textforit -f"
echo "  Restart:        sudo systemctl restart textforit"
echo "  Edit env:       nano backend/.env"
echo ""
