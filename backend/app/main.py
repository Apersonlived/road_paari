from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.endpoints import routing
from app.api.endpoints.user import router as user_router
from app.api.endpoints import auth, poi, notification

app = FastAPI(
    title="Road Paari API",
    description="Bus Route Optimizer with POI locator",
    version="1.0.0"
)

app.mount("/static", StaticFiles(directory="static"), name="static")

# Configure for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:*", 
        "*"  
    ],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(
    routing.router,
    prefix="/routing",
    tags=["routing"]
)

app.include_router(user_router, prefix="/users", tags=["users"])

app.include_router(poi.router, prefix="/poi", tags=["poi"])
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(notification.router, prefix="/notifications", tags=["notifications"])

@app.get("/")
def root():
    return {
        "message": "Road Paari API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )