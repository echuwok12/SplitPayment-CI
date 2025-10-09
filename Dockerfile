FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json* ./

COPY . .

RUN npm run build

EXPOSE 5000

CMD ["node", "server/index.js"]
