FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 9000

ENV DB_PATH=/app/data/bt_checkin.db
ENV API_KEY=change-me
ENV ALLOWED_ORIGINS=*

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "9000"]


