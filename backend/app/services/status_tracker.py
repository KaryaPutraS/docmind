from datetime import datetime, timezone
from typing import Dict, Any

# In-memory dictionary to track ongoing background tasks
# Key: msg_id (str)
# Value: dict with keys:
#   - status: str (e.g. "Downloading...", "Processing OCR...")
#   - filename: str
#   - sender: str
#   - started_at: datetime
#   - updated_at: datetime
_active_processes: Dict[str, Dict[str, Any]] = {}

def set_status(msg_id: str, status: str, filename: str = "Unknown", sender: str = "Unknown"):
    now = datetime.now(timezone.utc)
    if msg_id not in _active_processes:
        _active_processes[msg_id] = {
            "started_at": now.isoformat(),
            "filename": filename,
            "sender": sender
        }
    _active_processes[msg_id]["status"] = status
    _active_processes[msg_id]["updated_at"] = now.isoformat()

def clear_status(msg_id: str):
    if msg_id in _active_processes:
        del _active_processes[msg_id]

def get_all_statuses() -> list[Dict[str, Any]]:
    # Return as list, optionally sorting by updated_at
    items = []
    for msg_id, data in _active_processes.items():
        items.append({
            "msg_id": msg_id,
            **data
        })
    return items
