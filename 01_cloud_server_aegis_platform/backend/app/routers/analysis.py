import os
import requests
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime, timedelta
from ..database import get_db
from .. import models

router = APIRouter(prefix="/api/v1/analysis", tags=["Analysis"])

QWEN_API_KEY = os.getenv("QWEN_API_KEY", "")
QWEN_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

class ChatRequest(BaseModel):
    question: str
    context: str

@router.get("/current")
def get_ai_analysis(db: Session = Depends(get_db)):
    now = datetime.utcnow()
    recent_events = db.query(models.Event).filter(models.Event.timestamp >= now - timedelta(minutes=15)).all()
    count = len(recent_events)
    
    # 🌟 核心修復：動態判定系統狀態
    state = "safe"
    if any(e.severity == 'critical' for e in recent_events):
        state = "critical"
    elif any(e.severity == 'high' for e in recent_events):
        state = "warning"
        
    return {"status": "success", "count": count, "state": state}

@router.get("/qwen-insight")
def get_qwen_insight(db: Session = Depends(get_db)):
    events = db.query(models.Event).filter(models.Event.severity.in_(['critical', 'high', 'info'])).order_by(models.Event.timestamp.desc()).limit(500).all()
    if not events: return {"status": "success", "report": "No sufficient data for AI analysis yet."}
    data_str = "\n".join([f"[{e.timestamp}] ID:{e.device_id} | Event:{e.event_name} | Sev:{e.severity} | Desc:{e.description}" for e in events])
    prompt = f"You are the AI Security Analyst for 'AI-SafeGuard'. Analyze the following recent IoT events.\nREQUIREMENTS:\n- Provide the report in English.\n- Keep it EXTREMELY concise (under 100 words).\n- Use bullet points only.\n- Format: 1. Status Overview 2. Threat Correlation 3. Action Required.\nData:\n{data_str}"
    headers = {"Authorization": f"Bearer {QWEN_API_KEY}", "Content-Type": "application/json"}
    payload = {"model": "qwen-plus", "messages": [{"role": "system", "content": "You are an AIoT expert."}, {"role": "user", "content": prompt}]}
    try:
        resp = requests.post(QWEN_URL, headers=headers, json=payload, timeout=40)
        return {"status": "success", "report": resp.json()["choices"][0]["message"]["content"]}
    except Exception as e: return {"status": "error", "report": f"AI Error: {str(e)}"}

@router.post("/chat")
def chat_with_ai(req: ChatRequest):
    prompt = f"Based on this report: '{req.context}', answer concisely. CRITICAL RULE: Answer in the EXACT SAME LANGUAGE as the user.\nUser Question: {req.question}"
    headers = {"Authorization": f"Bearer {QWEN_API_KEY}", "Content-Type": "application/json"}
    payload = {"model": "qwen-plus", "messages": [{"role": "user", "content": prompt}]}
    try:
        resp = requests.post(QWEN_URL, headers=headers, json=payload, timeout=30)
        return {"status": "success", "answer": resp.json()["choices"][0]["message"]["content"]}
    except Exception: return {"status": "error", "answer": "Connection failed."}
