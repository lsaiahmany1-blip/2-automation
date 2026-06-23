FROM node:20-alpine AS dependencies

WORKDIR /usr/src/app

COPY app/package*.json ./
RUN npm install --omit=dev && npm cache clean --force

FROM node:20-alpine AS runtime

ENV NODE_ENV=production \
    PORT=8080

WORKDIR /usr/src/app

RUN addgroup -S -g 10001 pacman && adduser -S -u 10001 -G pacman pacman

COPY --from=dependencies /usr/src/app/node_modules ./node_modules
COPY app/ ./

USER 10001:10001

EXPOSE 8080

CMD ["npm", "start"]
