# Build Stage
# Build Stage
FROM golang:alpine AS builder

WORKDIR /app

# Copy Go Module files
COPY go.mod go.sum ./
RUN go mod download

# Copy Source Code
COPY . .

# Build Panel
RUN go build -o horizon-panel ./cmd/horizon/main.go

# Runtime Stage
FROM alpine:latest

WORKDIR /root/

# Install SQLite support
RUN apk add --no-cache sqlite ca-certificates

COPY --from=builder /app/horizon-panel .
# Copy static files for frontend if needed? 
# Assuming frontend is built separately or served via Next.js separately. 
# For now, this Dockerfile is for the GO BACKEND.

# Expose API Port
EXPOSE 8080

CMD ["./horizon-panel"]
