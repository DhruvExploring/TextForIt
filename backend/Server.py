from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from logic import get_llm_response
import os
from dotenv import load_dotenv
load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/transcript")
def read_root(link: str):
    try:
        return get_llm_response(link)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return "Something went wrong. Please paste a valid public YouTube URL."