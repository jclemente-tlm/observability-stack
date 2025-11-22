FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY auth_service.py .

ENV KEYCLOAK_URL=http://keycloak:8080
ENV KEYCLOAK_REALM=observability

EXPOSE 8000

CMD ["python", "auth_service.py"]
