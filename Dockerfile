FROM node:20 AS builder

WORKDIR /app

ARG GITHUB_SHA=local-dev
ENV GITHUB_SHA=$GITHUB_SHA

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /app


ENV NODE_ENV=production

COPY --from=builder /app/server.js ./server.js
COPY --from=builder /app/public ./public
COPY --from=builder /app/dist/build-manifest.json ./dist/build-manifest.json

USER node

EXPOSE 4173

CMD ["node", "server.js"]
