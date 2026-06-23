FROM node:20-alpine AS dependencies

WORKDIR /usr/src/app

COPY app/package*.json ./
RUN npm install --omit=dev && npm cache clean --force

FROM node:20-alpine AS runtime

ENV NODE_ENV=production \
    PORT=8080

WORKDIR /usr/src/app

RUN addgroup -S pacman && adduser -S pacman -G pacman

COPY --from=dependencies /usr/src/app/node_modules ./node_modules
COPY app/ ./

USER pacman

EXPOSE 8080

CMD ["npm", "start"]
