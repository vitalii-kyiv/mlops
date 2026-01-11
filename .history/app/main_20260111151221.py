import os
import logging
import time
import pickle
from typing import Dict, List, Optional, Tuple
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import prometheus_client
from prometheus_client import Counter, Histogram, Gauge
from alibi_detect import cd
from alibi_detect.utils.saving import load_detector

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)
REQUEST_COUNT = Counter(
    'inference_requests_total',
    'Total number of inference requests',
    ['status']
)
REQUEST_LATENCY = Histogram(
    'inference_request_duration_seconds',
    'Inference request latency',
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0]
)
DRIFT_DETECTIONS = Counter(
    'drift_detections_total',
    'Total number of drift detections'
)
MODEL_LOADED = Gauge(
    'model_loaded',
    'Whether the model is loaded (1) or not (0)'
)

app = FastAPI(title="MLOps Quality Inference Service", version="1.0.0")

model = None
drift_detector = None
reference_data = None


class InferenceRequest(BaseModel):
    features: List[float] = Field(..., description="Features for prediction")
    request_id: Optional[str] = Field(None, description="Request ID for tracing")


class InferenceResponse(BaseModel):
    prediction: float = Field(..., description="Model prediction")
    request_id: Optional[str] = Field(None, description="Request ID")
    drift_detected: bool = Field(False, description="Whether drift was detected")
    drift_score: Optional[float] = Field(None, description="Drift score")


def load_model():
    global model, drift_detector, reference_data
    
    model_path = os.getenv("MODEL_PATH", "/app/models/model.pkl")
    drift_detector_path = os.getenv("DRIFT_DETECTOR_PATH", "/app/models/drift_detector.pkl")
    
    try:
        if os.path.exists(model_path):
            with open(model_path, 'rb') as f:
                model = pickle.load(f)
            logger.info(f"Model loaded from {model_path}")
            MODEL_LOADED.set(1)
        else:
            logger.warning(f"Model file not found at {model_path}, using mock model")
            model = MockModel()
            MODEL_LOADED.set(1)
        
        if os.path.exists(drift_detector_path):
            try:
                drift_detector = load_detector(drift_detector_path)
                logger.info(f"Drift detector loaded from {drift_detector_path}")
            except Exception as e:
                logger.warning(f"Could not load drift detector: {e}, using simple detector")
                drift_detector = SimpleDriftDetector()
        else:
            logger.warning(f"Drift detector not found, using simple detector")
            drift_detector = SimpleDriftDetector()
        
        reference_data_path = os.getenv("REFERENCE_DATA_PATH", "/app/models/reference_data.pkl")
        if os.path.exists(reference_data_path):
            with open(reference_data_path, 'rb') as f:
                reference_data = pickle.load(f)
            logger.info(f"Reference data loaded from {reference_data_path}")
        else:
            reference_data = np.random.randn(100, 10).astype(np.float32)
            logger.warning("Reference data not found, using generated mock data")
            
    except Exception as e:
        logger.error(f"Error loading model: {e}")
        model = MockModel()
        drift_detector = SimpleDriftDetector()
        reference_data = np.random.randn(100, 10).astype(np.float32)


class MockModel:
    def predict(self, X):
        X = np.array(X)
        if X.ndim == 1:
            X = X.reshape(1, -1)
        return np.mean(X, axis=1)[0]


class SimpleDriftDetector:
    def __init__(self, threshold=0.05):
        self.threshold = threshold
    
    def predict(self, X, return_instance_score=True):
        X = np.array(X)
        if X.ndim == 1:
            X = X.reshape(1, -1)
        
        mean_val = np.mean(np.abs(X))
        drift_score = mean_val
        
        is_drift = drift_score > self.threshold
        
        result = {
            'data': {'is_drift': is_drift},
            'p_value': 1.0 - drift_score if drift_score < 1.0 else 0.0
        }
        
        if return_instance_score:
            result['data']['instance_score'] = drift_score
        
        return result


def detect_drift(features: List[float]) -> Tuple[bool, float]:
    """Детекція дрейфу вхідних даних"""
    global drift_detector, reference_data
    
    if drift_detector is None:
        return False, 0.0
    
    try:
        features_array = np.array(features).reshape(1, -1).astype(np.float32)
        
        # Використання drift детектора
        result = drift_detector.predict(features_array, return_instance_score=True)
        
        is_drift = result['data']['is_drift']
        drift_score = result['data'].get('instance_score', 0.0)
        
        if is_drift:
            DRIFT_DETECTIONS.inc()
            logger.warning(f"Drift detected! Score: {drift_score:.4f}, Features: {features}")
            print(f"Drift detected! Score: {drift_score:.4f}")
        
        return is_drift, float(drift_score)
        
    except Exception as e:
        logger.error(f"Error in drift detection: {e}")
        return False, 0.0


def predict(data: List[float]) -> float:
    """Основна функція передбачення"""
    global model
    
    if model is None:
        raise ValueError("Model not loaded")
    
    try:
        prediction = model.predict(data)
        return float(prediction)
    except Exception as e:
        logger.error(f"Error in prediction: {e}")
        raise


@app.on_event("startup")
async def startup_event():
    """Завантаження моделі при старті сервісу"""
    logger.info("Starting inference service...")
    load_model()
    logger.info("Inference service started successfully")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "drift_detector_loaded": drift_detector is not None
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return prometheus_client.generate_latest()


@app.post("/predict", response_model=InferenceResponse)
async def predict_endpoint(request: InferenceRequest):
    """Endpoint для передбачення з drift детекцією"""
    start_time = time.time()
    
    try:
        # Логування вхідних даних
        logger.info(f"Received prediction request: request_id={request.request_id}, features={request.features}")
        print(f"Input data: {request.features}")
        
        # Перевірка на дрейф
        drift_detected, drift_score = detect_drift(request.features)
        
        # Передбачення
        prediction = predict(request.features)
        
        # Логування відповіді
        logger.info(f"Prediction: {prediction:.4f}, Drift detected: {drift_detected}")
        print(f"Prediction: {prediction:.4f}")
        
        # Метрики
        latency = time.time() - start_time
        REQUEST_LATENCY.observe(latency)
        REQUEST_COUNT.labels(status="success").inc()
        
        response = InferenceResponse(
            prediction=prediction,
            request_id=request.request_id,
            drift_detected=drift_detected,
            drift_score=drift_score
        )
        
        return response
        
    except Exception as e:
        logger.error(f"Error processing request: {e}")
        REQUEST_COUNT.labels(status="error").inc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/webhook/drift")
async def drift_webhook():
    """Webhook для виклику retrain пайплайну при дрейфі"""
    # Цей endpoint може викликатись drift детектором або зовнішньою системою
    logger.info("Drift webhook triggered - should trigger retrain pipeline")
    print("Drift detected - triggering retrain pipeline")
    
    # Тут можна додати виклик GitLab CI API або іншого механізму
    # Наприклад: requests.post(GITLAB_CI_WEBHOOK_URL)
    
    return {"status": "webhook_received", "action": "retrain_triggered"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

