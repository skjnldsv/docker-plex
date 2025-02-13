## A linuxserver plex image that supports AMD transcoding

Easy as it sounds, just see the linuxserver docs: https://docs.linuxserver.io/images/docker-plex/

Use the image `ghcr.io/skjnldsv/docker-plex:nightly`.
Also make sure you pass your amd device like so:

```yml
    devices:
      - /dev/dri:/dev/dri
```

### Full example
```yml
version: "3.7"

services:
  plex:
    image: ghcr.io/skjnldsv/docker-plex:nightly
    restart: unless-stopped
    container_name: plex

    ports:

      # Default access
      - target: 32400
        published: 32400
        mode: host
 
      # https://support.plex.tv/articles/201543147-what-network-ports-do-i-need-to-allow-through-my-firewall/
      # Plex Home Theater control
      - 8324:8324/tcp

      # GDM discovery
      - 32410:32410/udp
      - 32412:32412/udp
      - 32413:32413/udp
      - 32414:32414/udp

    environment:
      - TZ=Europe/Berlin
      - VERSION=docker

    devices:
      - /dev/dri:/dev/dri
    volumes:
      - /mnt/config:/config
      - /mnt/storage:/storage
```
