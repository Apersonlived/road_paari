import os, json, logging
import firebase_admin
from firebase_admin import credentials, messaging

logger = logging.getLogger(__name__)

def _init_app():
    if firebase_admin._apps:
        return
    raw = os.getenv("FIREBASE_CREDENTIALS_JSON")
    if raw:
        cred = credentials.Certificate(json.loads(raw))
    else:
        # falls back to GOOGLE_APPLICATION_CREDENTIALS env var
        cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred)

_init_app()

def send_push(
    fcm_token: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """Send a push notification to a single device. Returns True on success."""
    print(f"Sending push notification to {fcm_token}") 
    print(f"Title: {title}, Body: {body}, Data: {data}") 
    try:
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=fcm_token,
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default")
                )
            ),
        )
        messaging.send(msg)
        return True
    except Exception as e:
        logger.error(f"FCM send failed: {e}")
        return False