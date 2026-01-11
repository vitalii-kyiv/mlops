import os
import pickle
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from alibi_detect import cd
from alibi_detect.utils.saving import save_detector
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def generate_synthetic_data(n_samples=1000, n_features=10, seed=42):
    np.random.seed(seed)
    X = np.random.randn(n_samples, n_features).astype(np.float32)
    y = np.mean(X, axis=1) + np.random.randn(n_samples) * 0.1
    return X, y


def train_model(X_train, y_train):
    logger.info(f"Training model on {len(X_train)} samples")
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    logger.info("Model training completed")
    return model


def train_drift_detector(X_reference):
    logger.info(f"Training drift detector on {len(X_reference)} reference samples")
    
    detector = cd.KSDrift(
        X_reference,
        p_val=0.05,
        alternative='two-sided'
    )
    
    logger.info("Drift detector training completed")
    return detector


def main():
    model_output_path = os.getenv("MODEL_OUTPUT_PATH", "models/model.pkl")
    drift_detector_output_path = os.getenv("DRIFT_DETECTOR_OUTPUT_PATH", "models/drift_detector.pkl")
    reference_data_output_path = os.getenv("REFERENCE_DATA_OUTPUT_PATH", "models/reference_data.pkl")
    
    os.makedirs(os.path.dirname(model_output_path), exist_ok=True)
    
    logger.info("Generating synthetic training data...")
    X, y = generate_synthetic_data(n_samples=1000, n_features=10)
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    model = train_model(X_train, y_train)
    
    train_score = model.score(X_train, y_train)
    test_score = model.score(X_test, y_test)
    logger.info(f"Model train score: {train_score:.4f}")
    logger.info(f"Model test score: {test_score:.4f}")
    
    with open(model_output_path, 'wb') as f:
        pickle.dump(model, f)
    logger.info(f"Model saved to {model_output_path}")
    
    drift_detector = train_drift_detector(X_train)
    
    save_detector(drift_detector, drift_detector_output_path)
    logger.info(f"Drift detector saved to {drift_detector_output_path}")
    
    with open(reference_data_output_path, 'wb') as f:
        pickle.dump(X_train, f)
    logger.info(f"Reference data saved to {reference_data_output_path}")
    
    logger.info("Training pipeline completed successfully!")


if __name__ == "__main__":
    main()

