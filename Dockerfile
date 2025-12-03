# ============================================================================
# SCB MCP Server - Multi-stage Docker Build
# ============================================================================
# This Dockerfile creates a production-ready container for the SCB MCP server
# with proper security practices (non-root user) and health monitoring.
# ============================================================================

# ----------------------------------------------------------------------------
# Stage 1: Build
# ----------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies separately to leverage Docker layer caching
# Skip lifecycle scripts so the "prepare" build step doesn't run before sources are copied
COPY package*.json ./
RUN npm ci --ignore-scripts

# Copy source files and build TypeScript
COPY . .
RUN npm run build

# Prune dev dependencies to keep the final image small
RUN npm prune --omit=dev

# ----------------------------------------------------------------------------
# Stage 2: Production
# ----------------------------------------------------------------------------
FROM node:20-alpine AS production

# Install curl for health checks
RUN apk add --no-cache curl

WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1000 app && \
    adduser -u 1000 -G app -s /bin/sh -D app

# Copy built application from builder stage
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --from=builder --chown=app:app /app/package.json ./
COPY --from=builder --chown=app:app /app/README.md ./

# Switch to non-root user
USER app

# Environment configuration
ENV NODE_ENV=production
ENV MCP_TRANSPORT=http
ENV PORT=3000

# Expose the HTTP port
EXPOSE 3000

# Health check configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start the HTTP server
CMD ["node", "dist/http-server.js"]
