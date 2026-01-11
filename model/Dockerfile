FROM python:3.11-slim

WORKDIR /workspace

COPY model/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY model/train.py .

RUN mkdir -p models

ENV MODEL_OUTPUT_PATH=models/model.pkl
ENV DRIFT_DETECTOR_OUTPUT_PATH=models/drift_detector.pkl
ENV REFERENCE_DATA_OUTPUT_PATH=models/reference_data.pkl

CMD ["python", "train.py"]

