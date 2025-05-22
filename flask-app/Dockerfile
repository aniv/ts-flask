# flask-app/Dockerfile for the Flask application
FROM python:3.9-slim-buster

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the Flask application
COPY app.py ./

# Expose the port Flask listens on. This doesn't map to the host,
# but tells Docker that this container accepts connections on this port.
EXPOSE 5000

# Command to run the Flask application
CMD ["python", "app.py"]
