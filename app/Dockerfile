FROM python:3.11-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

RUN mkdir -p /app/models

ENV MODEL_PATH=/app/models/model.pkl
ENV DRIFT_DETECTOR_PATH=/app/models/drift_detector.pkl
ENV REFERENCE_DATA_PATH=/app/models/reference_data.pkl

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/health')"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

