# Use official Python runtime as base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Set environment variable for non-interactive apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for pyodbc (unixodbc and ODBC driver)
RUN apt-get update && apt-get install -y --no-install-recommends \
  gnupg \
  curl \
  && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
  && curl -sSL https://packages.microsoft.com/config/debian/11/prod.list -o /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update \
  && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
  unixodbc \
  unixodbc-dev \
  msodbcsql18 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Expose port
EXPOSE 8000

# Run the app
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]