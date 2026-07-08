ARG OUTPUT=/output
FROM alpine:edge AS builder
RUN apk add --no-cache \
    autoconf \
    automake \
    binutils \
    cmake \
    curl \
    dpkg \
    file \
    g++ \
    gcc \
    git \
    libc6-compat \
    libdrm-dev \
    libtool \
    libxshmfence \
    linux-headers \
    make \
    mesa-va-gallium \
    musl-dev \
    nghttp2-dev \
    pkgconfig \
    xxd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FROM builder AS amd

ARG CFLAGS
ARG LDFLAGS
ARG MAKEFLAGS
ARG OUTPUT
ARG DESTDIR

WORKDIR /tmp/amd

RUN ls -la /usr/lib/
RUN ls -la /usr/lib/dri/

RUN apk add  xf86-video-amdgpu linux-firmware-amdgpu --no-cache --update-cache \
 && apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing libva-utils \
 && mkdir -p "$OUTPUT/usr/bin" "$OUTPUT/usr/lib/dri" "$OUTPUT/usr/share/libdrm" \
 && cp -a /usr/bin/vainfo "$OUTPUT/usr/bin" \
 && cp -aL /usr/lib/dri/*.so* "$OUTPUT/usr/lib/dri" \
 # Collect the COMPLETE ldd dependency closure of the VA drivers (+ vainfo)
 # instead of a hand-maintained library list. The old explicit list silently
 # dropped newly-introduced mesa dependencies (e.g. libSPIRV-Tools.so), which
 # made radeonsi_drv_video.so fail to dlopen on current Alpine mesa.
 && for pass in 1 2 3 4 5 6; do \
      for f in "$OUTPUT"/usr/lib/dri/*.so* "$OUTPUT"/usr/lib/*.so* "$OUTPUT"/usr/bin/vainfo; do \
        ldd "$f" 2>/dev/null | grep -oE '/[^ ]+\.so[^ )]*' || true; \
      done | sort -u | while read -r dep; do \
        b="$(basename "$dep")"; \
        case "$b" in libc.musl-*|ld-musl-*) continue;; esac; \
        [ -e "$OUTPUT/usr/lib/$b" ] || cp -aL "$dep" "$OUTPUT/usr/lib/$b" 2>/dev/null || true; \
      done; \
    done \
 # Stage the up-to-date musl loader/libc. Current mesa requires qsort_r, which
 # is missing from the musl bundled in plexmediaserver; ship it as both the
 # loader and libc.so so the symbol resolves.
 && cp -aL /lib/ld-musl-x86_64.so.1 "$OUTPUT/usr/lib/ld-musl-x86_64.so.1" \
 && cp -aL /lib/ld-musl-x86_64.so.1 "$OUTPUT/usr/lib/libc.so" \
 && cp -a /usr/share/libdrm/* "$OUTPUT/usr/share/libdrm"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
from ghcr.io/linuxserver/plex:latest
ARG OUTPUT

# Install AMD drivers
RUN apt-get update \
 && apt-get install -y software-properties-common

RUN add-apt-repository ppa:oibaf/graphics-drivers -y
RUN curl -sL --retry 3 https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add - \
 && add-apt-repository "deb https://repo.radeon.com/rocm/apt/latest $(lsb_release -s -c) main" -y

RUN apt-get update \
 && apt-get install -y \
	vainfo \
	mesa-va-drivers \
	mesa-vdpau-drivers \
	libdrm-amdgpu1 \
	libavutil58 \
	rocm-opencl-runtime \
 && apt-get clean

# Install the collected AMD VAAPI runtime into plexmediaserver's lib dir.
# The full dependency closure (drivers + libva + libdrm + the rest) is copied
# in, overwriting the stale musl libraries Plex bundles -- notably libdrm,
# whose bundled version lacks amdgpu_va_manager_alloc required by current mesa.
# The musl loader and libc.so are upgraded in place to provide qsort_r.
COPY --from=amd $OUTPUT/usr/lib/dri/*.so* /usr/lib/plexmediaserver/lib/dri/
COPY --from=amd $OUTPUT/usr/lib/ /tmp/amd-lib/
RUN set -eux; PLIB=/usr/lib/plexmediaserver/lib; \
    for f in /tmp/amd-lib/*.so*; do \
      cp -a "$f" "$PLIB/$(basename "$f")"; \
    done; \
    cp -a /tmp/amd-lib/ld-musl-x86_64.so.1 "$PLIB/ld-musl-x86_64.so.1"; \
    cp -a /tmp/amd-lib/libc.so "$PLIB/libc.so"; \
    rm -rf /tmp/amd-lib
