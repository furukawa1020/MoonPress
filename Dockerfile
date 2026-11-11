FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends bash build-essential ca-certificates curl git && rm -rf /var/lib/apt/lists/*
WORKDIR /src
ENV MOON_HOME=/opt/moon
ENV PATH=/opt/moon/bin:$PATH
COPY .moon-version ./
COPY scripts/setup.sh scripts/toolchain.lock ./scripts/
RUN bash scripts/setup.sh
RUN curl --fail --silent --show-error --location https://go.dev/dl/go1.27.4.linux-amd64.tar.gz -o /tmp/go.tar.gz \
    && printf '%s  %s\n' 7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840 /tmp/go.tar.gz | sha256sum --check --strict \
    && tar -xzf /tmp/go.tar.gz -C /usr/local && rm /tmp/go.tar.gz
COPY . .
RUN moon build --target native --release \
    && CGO_ENABLED=0 /usr/local/go/bin/go build -trimpath -o /tmp/moonpress-web deploy/web/main.go

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /data && chown 10001:10001 /data
COPY --from=build /src/_build/native/release/build/cmd/main/main.exe /usr/local/bin/moonpress
COPY --from=build /tmp/moonpress-web /usr/local/bin/moonpress-web
COPY deploy/web/entrypoint.sh /usr/local/bin/moonpress-entrypoint
VOLUME ["/data"]
EXPOSE 8080
ENTRYPOINT ["/bin/sh", "/usr/local/bin/moonpress-entrypoint"]
