from fastapi import APIRouter
from typing import List, Dict, Any

from app.services.status_tracker import get_all_statuses

router = APIRouter(prefix="/status", tags=["status"])

@router.get("/processing")
async def get_processing_status() -> List[Dict[str, Any]]:
    """
    Returns a list of currently active processing tasks from the webhook.
    """
    return get_all_statuses()
