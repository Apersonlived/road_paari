from app.core.database import engine
from sqlalchemy import text

def migrate():
    with engine.connect() as conn:
        # 1. Add fcm_token to app_user
        conn.execute(text("""
            ALTER TABLE app_user 
            ADD COLUMN IF NOT EXISTS fcm_token VARCHAR;
        """))

        # 2. Add poi_id to notification (nullable so existing rows are unaffected)
        conn.execute(text("""
            ALTER TABLE notification
            ADD COLUMN IF NOT EXISTS poi_id INTEGER
            REFERENCES poi(id) ON DELETE SET NULL;
        """))

        # 3. Add created_at to notification
        conn.execute(text("""
            ALTER TABLE notification
            ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ
            DEFAULT NOW();
        """))

        conn.commit()
        print("✅ Migration complete")

if __name__ == "__main__":
    migrate()