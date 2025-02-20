# base image
FROM alpine:3.20.1

# packages
RUN apk update && \
    apk add --no-cache openssh-client openssh-server socat

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# entry point
ENTRYPOINT ["/entrypoint.sh"]
