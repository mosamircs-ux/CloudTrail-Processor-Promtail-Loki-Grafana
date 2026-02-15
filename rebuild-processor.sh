# Quick Fix Commands for me-south-1 Issue

# Stop all containers
docker compose down

# Rebuild the processor container with the fix
docker compose build cloudtrail-processor

# Start all containers
docker compose up -d

# Watch the logs to verify it's working
docker logs -f cloudtrail-processor

# If you want to see just the recent logs
docker logs --tail 50 cloudtrail-processor

# Check if all containers are running
docker compose ps
