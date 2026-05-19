#!/bin/bash
# TextForIt — EC2 deployment script (Ubuntu 22.04, ARM64)

set -e

echo "================================================="
echo "   TextForIt Deploying..."
echo "================================================="

# ── System packages ────────────────────────────────
echo "[1/6] Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-venv python3-pip git curl nginx

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# ── Backend ────────────────────────────────────────
echo "[2/6] Setting up backend..."
cd backend

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q

cd ..

# ── Frontend ───────────────────────────────────────
echo "[3/6] Building frontend..."
cd frontend

if [ ! -d "node_modules" ]; then
    npm install
fi

npm run build

# Nginx (www-data) needs execute on the home dir to traverse into frontend/dist
sudo chmod o+x /home/ubuntu

cd ..

# ── systemd service ────────────────────────────────
echo "[4/6] Configuring systemd service..."

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

# ── Nginx ──────────────────────────────────────────
echo "[5/6] Configuring Nginx..."

sudo tee /etc/nginx/sites-available/textforit > /dev/null << EOF
server {
    listen 80;
    server_name _;

    location / {
        root ${PROJECT_DIR}/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/textforit /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl restart nginx

# ── Environment ────────────────────────────────────
echo "[6/6] Checking environment..."

if [ ! -f "backend/.env" ]; then
    cat > backend/.env << EOF
GOOGLE_API_KEY=your_gemini_api_key_here
EOF
    echo "WARNING: Created .env template — set GOOGLE_API_KEY then restart:"
    echo "  nano backend/.env && sudo systemctl restart textforit"
else
    sudo systemctl restart textforit
fi

# ── Done ───────────────────────────────────────────
PUBLIC_IP=$(curl -s ifconfig.me)
echo ""
echo "================================================="
echo "   TextForIt is Live!"
echo "================================================="
echo "  App:     http://${PUBLIC_IP}"
echo "  API:     http://${PUBLIC_IP}/api"
echo ""
echo "  Status:  sudo systemctl status textforit"
echo "  Logs:    sudo journalctl -u textforit -f"
echo "  Restart: sudo systemctl restart textforit"
echo ""
