FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential automake autoconf libtool pkg-config \
    libssl-dev git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/adrienverge/openfortivpn.git /src
WORKDIR /src
RUN ./autogen.sh && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make && \
    make install DESTDIR=/install

FROM debian:bookworm-slim

# CORREÇÃO: iproute2 e iptables adicionados para o roteamento funcionar
RUN apt-get update && apt-get install -y --no-install-recommends \
    ppp libssl3 ca-certificates iproute2 iptables procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install/usr/bin/openfortivpn /usr/bin/openfortivpn

ENTRYPOINT ["openfortivpn"]
CMD ["-c", "/etc/openfortivpn/config"]