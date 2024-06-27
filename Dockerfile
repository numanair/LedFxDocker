FROM python:3.12.4-bookworm AS primary
WORKDIR /app

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
	git \
	libportaudio2 \
	avahi-daemon \
	alsa-utils \
	libnss-mdns \
	libavahi-client3 \
	libavahi-common3 \
	libvorbisidec1 \
	pulseaudio \
	cmake
RUN pip install --upgrade pip wheel setuptools
RUN pip install numpy
RUN pip install git+https://github.com/LedFx/LedFx

RUN adduser root pulse-access

# https://web.archive.org/web/20230527143933/https://gnanesh.me/avahi-docker-non-root.html
RUN echo '*' > /etc/mdns.allow \
	&& sed -i "s/hosts:.*/hosts:          files mdns4 dns/g" /etc/nsswitch.conf \
	&& printf "[server]\nenable-dbus=no\n" >> /etc/avahi/avahi-daemon.conf \
	&& chmod 777 /etc/avahi/avahi-daemon.conf \
	&& mkdir -p /var/run/avahi-daemon \
	&& chown avahi:avahi /var/run/avahi-daemon \
	&& chmod 777 /var/run/avahi-daemon

# Get snapcast.deb for correct platform and copy to primary context
FROM primary AS snapcast
RUN pip install lastversion
ARG TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/arm/v7" ]; then ARCHITECTURE=armhf; elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then ARCHITECTURE=armhf; else ARCHITECTURE=amd64; fi \
	&& lastversion download badaix/snapcast --format assets --filter "^snapclient_(?:(\d+)\.)?(?:(\d+)\.)?(?:(\d+)\-)?(?:(\d)(_$ARCHITECTURE\-bookworm.deb))$" -o snapclient.deb

FROM primary
COPY --from=snapcast /app/snapclient.deb .
RUN apt-get install -fy ./snapclient.deb

COPY setup-files/ /app/
RUN chmod a+wrx /app/*

ENTRYPOINT ./entrypoint.sh
