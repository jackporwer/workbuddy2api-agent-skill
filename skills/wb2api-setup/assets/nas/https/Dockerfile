# Build the same DNS provider used by the reference NAS deployment.
# Standard Caddy images do not contain dns.providers.duckdns.
ARG CADDY_VERSION=2.11.7
FROM caddy:${CADDY_VERSION}-builder AS builder
ARG CADDY_VERSION
ARG DUCKDNS_VERSION=v0.5.0
RUN xcaddy build v${CADDY_VERSION} --with github.com/caddy-dns/duckdns@${DUCKDNS_VERSION}

FROM caddy:${CADDY_VERSION}-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
RUN /usr/bin/caddy list-modules | grep -Fx dns.providers.duckdns
ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
