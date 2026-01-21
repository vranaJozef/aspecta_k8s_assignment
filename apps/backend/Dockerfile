FROM python:3.12.1-alpine3.19 AS builder

WORKDIR /app

# Install build dependencies
# hadolint ignore=DL3018
RUN apk add --no-cache gcc musl-dev

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip==24.0 && \
    pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12.1-alpine3.19 AS runner

WORKDIR /app

ENV PYTHONUNBUFFERED=1

# Using UID 1000 for K8s runAsNonRoot compatibility
RUN addgroup -S appgroup && adduser -S -u 1000 appuser -G appgroup

COPY --from=builder /install /usr/local

COPY app.py .

# Switch to non-root user
USER 1000

EXPOSE 5000

ENTRYPOINT ["gunicorn"]
CMD ["--bind", "0.0.0.0:5000", "app:app"]
