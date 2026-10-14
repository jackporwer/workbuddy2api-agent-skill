# Derived deployment wrapper for linguo2625469/workbuddy2api-panel releases.
# build.ps1 places the verified Linux binary and its sample config in the context.
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata wget \
 && adduser -D -u 10001 app \
 && mkdir -p /app/auths /app/data /app/conf \
 && chown -R app:app /app
WORKDIR /app
COPY wb2api /app/wb2api
COPY config.example.json /app/conf/config.json
RUN chmod 755 /app/wb2api && chown app:app /app/conf/config.json
USER app
EXPOSE 7863
# An empty account pool returns 503; Docker health reports that condition too.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:7863/healthz || exit 1
ENTRYPOINT ["/app/wb2api"]
CMD ["-config", "/app/conf/config.json"]
