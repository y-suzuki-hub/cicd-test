FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
# 実行時に npm / yarn は使わない。同梱の npm の部品に脆弱性が見つかることがあるので、
# 依存を入れ終えたら消して、本番のコンテナに持ち込まない。
RUN npm ci --omit=dev \
 && rm -rf /usr/local/lib/node_modules /usr/local/bin/npm /usr/local/bin/npx \
           /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/yarnpkg /opt/yarn-*
COPY src ./src
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
