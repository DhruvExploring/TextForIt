#!/bin/bash

# Exit on any error
set -e

echo "Starting TextForIt Local Setup..."

# 1. Setup Backend
echo "Setting up Backend..."
cd backend
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi
echo "Activating virtual environment..."
source .venv/bin/activate
echo "Installing Python dependencies..."
pip install -r requirements.txt
cd ..

# 2. Setup Node dependencies
echo "Setting up React frontend..."
cd frontend
if [ ! -d "node_modules" ]; then
    echo "Installing Node dependencies..."
    npm install
fi
cd ..

# 3. Run Servers Concurrently
echo "Starting FastAPI Backend and Vite Frontend..."

# Start FastAPI in the background
cd backend
# The virtual environment was activated above
uvicorn Server:app --reload --port 8000 &
BACKEND_PID=$!
cd ..

# Start Vite in the background
cd frontend
npm run dev -- --port 5173 &
FRONTEND_PID=$!
cd ..

# Cleanup function to kill both servers on exit
cleanup() {
    echo "Stopping servers..."
    kill $BACKEND_PID
    kill $FRONTEND_PID
    exit
}

# Trap SIGINT (Ctrl+C) and call cleanup
trap cleanup SIGINT SIGTERM

echo "================================================="
echo "TextForIt is running locally!"
echo "Frontend: http://localhost:5173"
echo "Backend API: http://127.0.0.1:8000"
echo "Press Ctrl+C to stop both servers."
echo "================================================="

# Wait for background processes
wait $BACKEND_PID
wait $FRONTEND_PID
