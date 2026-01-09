FROM golang:1.25-alpine AS builder

WORKDIR /app

# Ensure static binary for easy deployment
ENV CGO_ENABLED=0 GOOS=linux

# Install build tools (if needed later)
RUN apk add --no-cache git

# Cache module downloads
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the backend source
COPY . .

# Build the backend binary
RUN go build -o server ./cmd

# ---
# Runtime image
FROM alpine:3.20

WORKDIR /app

# Create unprivileged user
RUN adduser -D -g '' appuser

# Copy compiled binary from builder stage
COPY --from=builder /app/server /app/server

EXPOSE 8080

USER appuser

CMD ["/app/server"]
