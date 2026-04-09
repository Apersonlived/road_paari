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
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "roadpaari-firebase-adminsdk-fbsvc-78bdd0dcf2.json")
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
        else:
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
    
if __name__ == "__main__":
    fcm_token = "d92JHZlAR9mQ_-99r-JfxH:APA91bHkSCCjYubnrc0wrrbSz2MD8zF3WylnjmRajKJRIhawne61mjzytajJS4sa6ZGTKnD5rRsCom3Mx2Je-KkkIzF_xSXBrdYOsmc0QD7OZWSJwsp0qO4"
    title = "Test Notification"
    body = "This is a test notification."
    data = {"key1": "value1", "key2": "value2"}

    result = send_push(fcm_token, title, body, data)
    print(f"Notification sent successfully: {result}")