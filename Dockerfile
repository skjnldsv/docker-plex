from ghcr.io/linuxserver/plex:latest

RUN \
 echo "**** install runtime packages ****" && \
 apt-get update && \
 apt-get install -y software-properties-common && \
 add-apt-repository ppa:oibaf/graphics-drivers -y && \
 apt-get update && \
 apt-get install -y \
	vainfo \
	mesa-va-drivers \
	mesa-vdpau-drivers \
	libdrm-amdgpu1 \
	libavutil56 && \
apt-get clean

RUN cp /lib/x86_64-linux-gnu/dri/* /usr/lib/plexmediaserver/lib/dri/
RUN cp /lib/x86_64-linux-gnu/libdrm_amdgpu.so.1.* /usr/lib/plexmediaserver/lib/libdrm_amdgpu.so.1
RUN cp /lib/x86_64-linux-gnu/libdrm.so.2.* /usr/lib/plexmediaserver/lib/libdrm.so.2
RUN cp /lib/x86_64-linux-gnu/libva-drm.so.2.* /usr/lib/plexmediaserver/lib/libva-drm.so.2
RUN cp /lib/x86_64-linux-gnu/libva.so.2.* /usr/lib/plexmediaserver/lib/libva.so.2
RUN cp /lib/x86_64-linux-gnu/libstdc++.so.6.* /usr/lib/plexmediaserver/lib/libstdc++.so.6
