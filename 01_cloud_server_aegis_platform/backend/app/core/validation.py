"""Validation shared by event, device and OTA file boundaries."""
import re
from fastapi import HTTPException

def safe_identifier(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", value) or ".." in value:
        raise HTTPException(status_code=400, detail="Invalid identifier or filename")
    return value
