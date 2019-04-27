FROM debian:stretch as builder

ENV FLB_VERSION 1.0.6

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      cmake \
      make \
      wget \
      unzip \
      libssl1.0-dev \
      libasl-dev \
      libsasl2-dev \
      pkg-config \
      libsystemd-dev \
      zlib1g-dev \
      flex \
      git \
      bison \
      ca-certificates

RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log
RUN git clone -b v$FLB_VERSION https://github.com/fluent/fluent-bit.git /tmp/
RUN rm -rf /tmp/build/*

WORKDIR /tmp/build/
RUN cmake -DFLB_DEBUG=Off \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_BUFFERING=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=On \
          -DFLB_IN_SYSTEMD=On \
          -DFLB_OUT_KAFKA=On ..

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN install bin/fluent-bit /fluent-bit/bin/

RUN cd ../conf && cp fluent-bit.conf \
     parsers.conf \
     parsers_java.conf \
     parsers_extra.conf \
     parsers_openstack.conf \
     parsers_cinder.conf \
     plugins.conf \
     /fluent-bit/etc/

FROM debian:stretch-slim 

COPY --from=builder /usr/lib/aarch64-linux-gnu/*sasl* /usr/lib/aarch64-linux-gnu/
COPY --from=builder /usr/lib/aarch64-linux-gnu/libz* /usr/lib/aarch64-linux-gnu/
COPY --from=builder /lib/aarch64-linux-gnu/libz* /lib/aarch64-linux-gnu/
COPY --from=builder /usr/lib/aarch64-linux-gnu/libssl.so* /usr/lib/aarch64-linux-gnu/
COPY --from=builder /usr/lib/aarch64-linux-gnu/libcrypto.so* /usr/lib/aarch64-linux-gnu/
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
COPY --from=builder /usr/share/ca-certificates /usr/share/ca-certificates

COPY --from=builder /fluent-bit /fluent-bit

EXPOSE 2020

# Entry point
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.conf"]
