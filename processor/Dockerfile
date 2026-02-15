FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY cloudtrail_processor.py .
COPY process_logs.sh .

# Make script executable
RUN chmod +x process_logs.sh

# Create directories
RUN mkdir -p /app/logs /app/processed

# Run the processor
CMD ["./process_logs.sh"]
