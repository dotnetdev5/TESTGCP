"""
Backend Service for AI Gateway
This service handles business logic and integrates with LiteLLM and Vertex AI
"""

import os
import logging
import asyncio
from typing import Dict, Any, Optional, List
from datetime import datetime
import json

from fastapi import FastAPI, HTTPException, Depends, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import httpx
import structlog
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from google.cloud import aiplatform
from google.auth import default

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Prometheus metrics
REQUEST_COUNT = Counter('backend_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('backend_request_duration_seconds', 'Request duration')
LITELLM_REQUESTS = Counter('litellm_requests_total', 'LiteLLM requests', ['model', 'status'])
VERTEX_AI_REQUESTS = Counter('vertex_ai_requests_total', 'Vertex AI requests', ['model', 'status'])

# Configuration
class Settings:
    def __init__(self):
        self.port = int(os.getenv("PORT", "8080"))
        self.litellm_url = os.getenv("LITELLM_URL", "http://litellm-service:4000")
        self.vertex_ai_project = os.getenv("VERTEX_AI_PROJECT", "")
        self.vertex_ai_region = os.getenv("VERTEX_AI_REGION", "us-central1")
        self.log_level = os.getenv("LOG_LEVEL", "INFO")
        self.environment = os.getenv("ENVIRONMENT", "production")

settings = Settings()

# Pydantic models
class ChatRequest(BaseModel):
    message: str = Field(..., description="User message")
    model: str = Field(default="gemini-pro", description="AI model to use")
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=2.0)
    max_tokens: Optional[int] = Field(default=1000, ge=1, le=4000)
    system_prompt: Optional[str] = Field(default=None, description="System prompt")
    conversation_id: Optional[str] = Field(default=None, description="Conversation ID")

class ChatResponse(BaseModel):
    response: str
    model: str
    tokens_used: Optional[int] = None
    conversation_id: Optional[str] = None
    timestamp: datetime
    processing_time: float

class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    version: str = "1.0.0"
    services: Dict[str, str]

class ErrorResponse(BaseModel):
    error: str
    message: str
    timestamp: datetime
    request_id: Optional[str] = None

# FastAPI app
app = FastAPI(
    title="AI Gateway Backend Service",
    description="Backend service for AI Gateway with LiteLLM and Vertex AI integration",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# HTTP client
http_client = httpx.AsyncClient(timeout=30.0)

# Vertex AI client
try:
    credentials, project = default()
    aiplatform.init(project=settings.vertex_ai_project, location=settings.vertex_ai_region)
    vertex_ai_available = True
except Exception as e:
    logger.warning("Vertex AI initialization failed", error=str(e))
    vertex_ai_available = False

# Middleware for request logging and metrics
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = asyncio.get_event_loop().time()
    
    # Generate request ID
    request_id = f"req_{int(start_time * 1000000)}"
    
    # Log request
    logger.info(
        "Request started",
        method=request.method,
        url=str(request.url),
        request_id=request_id,
        client_ip=request.client.host if request.client else None
    )
    
    try:
        response = await call_next(request)
        processing_time = asyncio.get_event_loop().time() - start_time
        
        # Update metrics
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()
        REQUEST_DURATION.observe(processing_time)
        
        # Log response
        logger.info(
            "Request completed",
            method=request.method,
            url=str(request.url),
            status_code=response.status_code,
            processing_time=processing_time,
            request_id=request_id
        )
        
        # Add request ID to response headers
        response.headers["X-Request-ID"] = request_id
        
        return response
        
    except Exception as e:
        processing_time = asyncio.get_event_loop().time() - start_time
        
        logger.error(
            "Request failed",
            method=request.method,
            url=str(request.url),
            error=str(e),
            processing_time=processing_time,
            request_id=request_id
        )
        
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=500
        ).inc()
        
        raise

# Health check endpoints
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    services = {}
    
    # Check LiteLLM
    try:
        async with http_client as client:
            response = await client.get(f"{settings.litellm_url}/health", timeout=5.0)
            services["litellm"] = "healthy" if response.status_code == 200 else "unhealthy"
    except Exception:
        services["litellm"] = "unhealthy"
    
    # Check Vertex AI
    services["vertex_ai"] = "healthy" if vertex_ai_available else "unhealthy"
    
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        services=services
    )

@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint"""
    return {"status": "ready", "timestamp": datetime.utcnow()}

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Chat endpoint
@app.post("/api/v1/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, background_tasks: BackgroundTasks):
    """
    Process chat request through LiteLLM
    """
    start_time = asyncio.get_event_loop().time()
    
    try:
        # Prepare request for LiteLLM
        litellm_request = {
            "model": request.model,
            "messages": [
                {"role": "user", "content": request.message}
            ],
            "temperature": request.temperature,
            "max_tokens": request.max_tokens
        }
        
        # Add system prompt if provided
        if request.system_prompt:
            litellm_request["messages"].insert(0, {
                "role": "system", 
                "content": request.system_prompt
            })
        
        # Call LiteLLM
        async with http_client as client:
            response = await client.post(
                f"{settings.litellm_url}/chat/completions",
                json=litellm_request,
                headers={"Content-Type": "application/json"},
                timeout=60.0
            )
            
            if response.status_code != 200:
                LITELLM_REQUESTS.labels(model=request.model, status="error").inc()
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"LiteLLM error: {response.text}"
                )
            
            result = response.json()
            LITELLM_REQUESTS.labels(model=request.model, status="success").inc()
        
        processing_time = asyncio.get_event_loop().time() - start_time
        
        # Extract response
        ai_response = result["choices"][0]["message"]["content"]
        tokens_used = result.get("usage", {}).get("total_tokens")
        
        # Log successful request
        background_tasks.add_task(
            log_chat_request,
            request.model,
            request.message,
            ai_response,
            processing_time,
            tokens_used
        )
        
        return ChatResponse(
            response=ai_response,
            model=request.model,
            tokens_used=tokens_used,
            conversation_id=request.conversation_id,
            timestamp=datetime.utcnow(),
            processing_time=processing_time
        )
        
    except httpx.TimeoutException:
        LITELLM_REQUESTS.labels(model=request.model, status="timeout").inc()
        raise HTTPException(status_code=504, detail="Request timeout")
    except httpx.RequestError as e:
        LITELLM_REQUESTS.labels(model=request.model, status="error").inc()
        raise HTTPException(status_code=502, detail=f"Connection error: {str(e)}")
    except Exception as e:
        LITELLM_REQUESTS.labels(model=request.model, status="error").inc()
        logger.error("Chat request failed", error=str(e), model=request.model)
        raise HTTPException(status_code=500, detail="Internal server error")

# Direct Vertex AI endpoint
@app.post("/api/v1/vertex-ai/chat")
async def vertex_ai_chat(request: ChatRequest):
    """
    Direct Vertex AI integration (bypass LiteLLM)
    """
    if not vertex_ai_available:
        raise HTTPException(status_code=503, detail="Vertex AI not available")
    
    start_time = asyncio.get_event_loop().time()
    
    try:
        from vertexai.preview.generative_models import GenerativeModel
        
        # Initialize model
        model = GenerativeModel(request.model)
        
        # Generate response
        response = model.generate_content(
            request.message,
            generation_config={
                "temperature": request.temperature,
                "max_output_tokens": request.max_tokens,
            }
        )
        
        processing_time = asyncio.get_event_loop().time() - start_time
        VERTEX_AI_REQUESTS.labels(model=request.model, status="success").inc()
        
        return ChatResponse(
            response=response.text,
            model=request.model,
            tokens_used=None,  # Vertex AI doesn't provide token count in this format
            conversation_id=request.conversation_id,
            timestamp=datetime.utcnow(),
            processing_time=processing_time
        )
        
    except Exception as e:
        VERTEX_AI_REQUESTS.labels(model=request.model, status="error").inc()
        logger.error("Vertex AI request failed", error=str(e), model=request.model)
        raise HTTPException(status_code=500, detail=f"Vertex AI error: {str(e)}")

# Models endpoint
@app.get("/api/v1/models")
async def list_models():
    """
    List available models from LiteLLM
    """
    try:
        async with http_client as client:
            response = await client.get(f"{settings.litellm_url}/models")
            if response.status_code == 200:
                return response.json()
            else:
                raise HTTPException(status_code=502, detail="Failed to fetch models")
    except Exception as e:
        logger.error("Failed to fetch models", error=str(e))
        raise HTTPException(status_code=500, detail="Internal server error")

# Background task for logging
async def log_chat_request(model: str, user_message: str, ai_response: str, 
                          processing_time: float, tokens_used: Optional[int]):
    """Log chat request details"""
    logger.info(
        "Chat request processed",
        model=model,
        user_message_length=len(user_message),
        ai_response_length=len(ai_response),
        processing_time=processing_time,
        tokens_used=tokens_used
    )

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=f"HTTP {exc.status_code}",
            message=exc.detail,
            timestamp=datetime.utcnow(),
            request_id=request.headers.get("X-Request-ID")
        ).dict()
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception", error=str(exc), path=request.url.path)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="Internal Server Error",
            message="An unexpected error occurred",
            timestamp=datetime.utcnow(),
            request_id=request.headers.get("X-Request-ID")
        ).dict()
    )

# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    logger.info("Backend service starting up", port=settings.port)

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Backend service shutting down")
    await http_client.aclose()

# Main entry point
if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=settings.port,
        log_level=settings.log_level.lower(),
        access_log=True,
        reload=settings.environment == "development"
    )
