FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . .
ENV NG_BUILD_MAX_WORKERS=1
ENV NG_BUILD_PARALLEL_TS=0
ENV NODE_OPTIONS=--max-old-space-size=512
RUN npm run build -- --configuration=development --no-progress --aot=false --optimization=false --source-map=false

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/dental-americana-frontend/browser /usr/share/nginx/html
EXPOSE 80
