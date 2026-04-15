# CommuniQ Pipecat Worker
#
# Build:  docker build -t communiq-pipecat-worker .
# Run:    docker run -p 9000:9000 --env-file .env communiq-pipecat-worker
#
# CP3 (local GPU models): use a CUDA base image and uncomment local deps
# in requirements.txt.

FROM python:3.11-slim

WORKDIR /app

# Install OS dependencies required by pydub/ffmpeg if local TTS is enabled.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 9000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "9000"]
