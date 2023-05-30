FROM node:14

RUN apk --no-cache add curl
RUN curl --version
RUN adduser -S appuser
WORKDIR /home/appuser/app
USER appuser
# Bundle app source
COPY . .
ENTRYPOINT ["sh", "-c", "node --max-old-space-size=4096 ./index.js" ]
