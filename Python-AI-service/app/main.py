from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import uvicorn
import requests
import openmeteo_requests
import requests_cache
import pandas as pd
from retry_requests import retry
from LLM.mistral import make_llm_call
from utils.constants import WEATHER_API_URL, GEOCODING_API_URL, EXTERNAL_INCIDENTS_URL
from typing import Optional

# Initialize FastAPI app
app = FastAPI()
host = os.getenv("HOST", "0.0.0.0")
port = int(os.getenv("PORT", 8000))

# Setup Open-Meteo client with cache and retry
cache_session = requests_cache.CachedSession('.cache', expire_after=3600)
retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
openmeteo = openmeteo_requests.Client(session=retry_session)

# Pydantic models
class LocationData(BaseModel):
    ip_address: Optional[str] = None
    location: str = None  # Both fields are now optional

class IncidentPayload(BaseModel):
    description: str
    incidentType: str

# Mapping of anomaly types to required departments
departments_needed = {
    "fire": ["fire department"],
    "flood": ["rescue team", "police"],
    "medical emergency": ["medical", "ambulance"]
}

# Function to resolve location to latitude/longitude using Open-Meteo Geocoding API
def get_coordinates_from_location(location: str) -> tuple[float, float]:
    """
    Converts a location name (e.g., "Berlin") to latitude and longitude using Open-Meteo Geocoding API.
    Returns (latitude, longitude) or raises an exception if not found.
    """
    try:
        params = {"name": location, "count": 1, "format": "json"}
        response = requests.get(GEOCODING_API_URL, params=params)
        response.raise_for_status()
        data = response.json()
        if "results" not in data or not data["results"]:
            raise Exception(f"No location found for {location}")
        result = data["results"][0]
        return result["latitude"], result["longitude"]
    except requests.RequestException as e:
        raise Exception(f"Geocoding API error: {str(e)}")

# Function to detect anomaly using Open-Meteo weather data
def detect_anomaly_from_weather(location: str) -> str:
    """
    Queries Open-Meteo API for weather data at the given location.
    Determines anomaly type based on temperature and precipitation.
    Returns the detected anomaly type or 'unknown' if no anomaly.
    """
    try:
        # Resolve location to coordinates
        latitude, longitude = get_coordinates_from_location(location)

        # Query Open-Meteo API for hourly forecast
        params = {
            "latitude": latitude,
            "longitude": longitude,
            "hourly": ["temperature_2m", "precipitation"]  # Add more variables as needed
        }
        responses = openmeteo.weather_api(WEATHER_API_URL, params=params)
        response = responses[0]  # Process first location

        # Process hourly data
        hourly = response.Hourly()
        hourly_temp = hourly.Variables(0).ValuesAsNumpy()  # temperature_2m
        hourly_precip = hourly.Variables(1).ValuesAsNumpy()  # precipitation

        # Get latest hourly data (last entry)
        latest_temp = hourly_temp[-1]
        latest_precip = hourly_precip[-1]

        # Anomaly detection logic
        if latest_temp > 35:  # Extreme heat
            return "fire"
        elif latest_precip > 5:  # Heavy precipitation (mm/h)
            return "flood"
        elif latest_temp < 0:  # Extreme cold
            return "medical emergency"

        return "unknown"
    except Exception as e:
        raise Exception(f"Weather API error: {str(e)}")

# Endpoint to detect anomalies
@app.post("/detect-anomaly")
async def detect_anomaly(data: LocationData):
    try:
        # Use provided location or resolve from IP if not provided (IP resolution TBD)
        location = data.location
        if not location:
            raise HTTPException(status_code=400, detail="Location not provided (IP resolution not implemented yet)")

        # Detect anomaly
        anomaly_type = detect_anomaly_from_weather(location)

        if anomaly_type == "unknown":
            return {"message": "No anomalies detected in your area."}

        # Generate description
        description_prompt = f"Generate a description for a potential {anomaly_type} incident in {location}."
        description = make_llm_call(description_prompt)

        # Determine departments
        departments = departments_needed.get(anomaly_type, [])

        # Generate notification
        notification_prompt = f"Generate a notification asking the user if they want to report this incident: {description} (type: {anomaly_type})."
        notification = make_llm_call(notification_prompt)

        return {
            "notification": notification,
            "description": description,
            "incident_type": anomaly_type,
            "departments": departments
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Endpoint to confirm and forward incident
@app.post("/confirm-incident")
async def confirm_incident(incident: IncidentPayload):
    try:
        payload = {
            "description": incident.description,
            "incidentType": incident.incidentType
        }
        response = requests.post(EXTERNAL_INCIDENTS_URL, json=payload)
        response.raise_for_status()
        return {"message": "Incident reported to external service successfully"}
    except requests.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Failed to report incident: {str(e)}")

# Run the app
if __name__ == "__main__":
    uvicorn.run(app, host=host, port=port)