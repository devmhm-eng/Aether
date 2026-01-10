# Build Stage
# Build Stage
FROM golang:alpine AS builder

WORKDIR /app

# Copy Go Module files
COPY go.mod go.sum ./
RUN go mod download

# Copy Source Code
COPY . .

# Build Agent
RUN go build -o horizon-agent ./cmd/server/main.go

# Runtime Stage
FROM alpine:latest

WORKDIR /root/

# Install Xray (Required dependency)
# We need to fetch xray or copy it. For now, let's assume we download it.
RUN apk add --no-cache curl unzip \
    && curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
    && unzip xray.zip -d /usr/bin/ \
    && chmod +x /usr/bin/xray \
    && rm xray.zip

COPY --from=builder /app/horizon-agent .

# Expose Admin Port
EXPOSE 8081

# Environment Variables
ENV ADMIN_PORT=8081
ENV MASTER_KEY=""

CMD ["./horizon-agent"]
