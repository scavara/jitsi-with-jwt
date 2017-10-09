FROM debian:9
MAINTAINER Sasa Cavara <scavara@gmail.com>
ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm
# customize - start
ENV DOMAIN example.com 
ENV CA CA.crt   
ENV KEY example.com.key 
ENV CRT example.com.crt
# customize - end
RUN apt-get update && \
	apt-get --quiet install -y apt-utils apt-transport-https gnupg wget procps apache2 patch && \
	apt-get --quiet install -y lsb-release lua-cjson-dev luarocks lua-bitop libssl1.0-dev lua-expat lua-filesystem lua-socket lua5.1 lua-sec lua-event lua-zlib && \
	wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | apt-key --quiet add && \
	echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi.list && \
        wget -qO - https://prosody.im/files/prosody-debian-packages.key | apt-key --quiet add - && \
        echo 'deb http://packages.prosody.im/debian stretch main' > /etc/apt/sources.list.d/prosody-trunk.list && \
	apt-get --quiet update 
COPY luas-in-usr-local.tar.gz /tmp/
RUN tar -zxf /tmp/luas-in-usr-local.tar.gz -C /
RUN apt-get -y install jicofo jitsi-meet jitsi-meet-prosody jitsi-meet-web jitsi-meet-web-config jitsi-videobridge jigasi prosody-trunk libssl-dev
COPY jitsi-meet-tokens_1.0.2084-1_all.deb /tmp/
RUN dpkg -i /tmp/jitsi-meet-tokens_1.0.2084-1_all.deb
RUN echo "jitsi-meet-tokens hold" | dpkg --set-selections
RUN apt-get clean
COPY $CA /etc/ssl
COPY $KEY /etc/ssl/private
RUN chmod 400 /etc/ssl/private/$KEY
COPY $CRT /etc/ssl/certs
RUN a2dissite 000-default
RUN a2enmod rewrite ssl headers proxy
RUN mkdir /etc/prosody/conf.avail
EXPOSE 80 443 5347
EXPOSE 10000-20000/udp
COPY watermark.png /tmp/
COPY favicon.ico /tmp/
COPY run.sh run.sh

