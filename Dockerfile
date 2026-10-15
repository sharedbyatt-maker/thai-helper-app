FROM ubuntu:24.04 AS web
ENV DEBIAN_FRONTEND=noninteractive CI=true FLUTTER_SUPPRESS_ANALYTICS=true
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils python3 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
WORKDIR /build/flutter_app
COPY flutter_app/pubspec.* ./
RUN flutter pub get
COPY flutter_app/ ./
COPY scripts/ /build/scripts/
RUN python3 /build/scripts/fetch_fonts.py
RUN flutter build web --release --no-web-resources-cdn

FROM python:3.12-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 EXCHANGE_DATABASE=/data/exchange.sqlite3 WEB_BUILD=/app/web
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home appuser && mkdir /data && chown appuser /data
COPY backend/app.py ./app.py
COPY backend/admin ./admin
COPY --from=web /build/flutter_app/build/web ./web
USER appuser
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "app:app"]
