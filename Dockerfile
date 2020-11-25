FROM alpine:3.12

ARG JETTY_VERSION=9.4.35.v20201120
ARG PLANTUML_VERSION=1.2020.20

ENV ALLOW_PLANTUML_INCLUDE=true
ENV JAVA_HOME=/usr/lib/jvm/zulu13-ca
ENV JETTY_BASE=/home/jetty
ENV JETTY_HOME=/home/jetty
ENV HOME=/home/jetty
ENV LANG=C.UTF-8
ENV MAVEN_OPTS=-Xmx2G
ENV PLANTUML_LIMIT_SIZE=16384
ENV PATH="${JAVA_HOME}:$PATH"

RUN apk --no-cache add \
  curl \
  fontconfig \
  freetype \
  gd \
  ghostscript-fonts \
  graphviz \
  make \
  ncurses ncurses-terminfo \
  readline \
  shadow \
  && apk --no-cache add -X "https://dl-cdn.alpinelinux.org/alpine/edge/testing" font-fira-code

# Install JRE
WORKDIR /etc/apk/keys
RUN  curl -fsSLO "https://cdn.azul.com/public_keys/alpine-signing@azul.com-5d5dc44c.rsa.pub" \
  && echo "https://repos.azul.com/zulu/alpine" >> /etc/apk/repositories \
  && apk --no-cache add zulu13-jre

# Install Jetty
WORKDIR /home/jetty
RUN set -o pipefail && curl -fsSL "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/${JETTY_VERSION}/jetty-distribution-${JETTY_VERSION}.tar.gz" | tar xzp --strip-components=1

# Install PlantUML
WORKDIR /home/jetty/webapps
RUN curl -f#SLo ROOT.war "https://github.com/plantuml/plantuml-server/releases/download/v${PLANTUML_VERSION}/plantuml-v${PLANTUML_VERSION}.war"

# Install Mulish as a free-to-use alternative to the internal Rakuten Sans font.
# See https://fonts.google.com/specimen/Mulish
WORKDIR /usr/share/fonts/rakuten-sans
RUN  apk --no-cache add --virtual fonttools -X "https://dl-cdn.alpinelinux.org/alpine/v3.12/community" py3-fonttools \
  && curl -fsSLo mulish.zip "https://fonts.google.com/download?family=Mulish" \
  && unzip -j mulish.zip 'static/*.ttf' \
  && rm -f mulish.zip \
  && echo "Decompiling fonts…" \
  && find . -name \*.ttf -print -exec ttx -q -i {} + \
  && echo "Renaming fonts…" \
  && find . -name \*.ttx -print -exec sed -E -i 's/Mulish/Rakuten Sans/g' {} \; \
  && echo "Recompiling fonts…" \
  && find . -name \*.ttx -print -exec ttx -q -f {} + \
  && apk del -X "https://dl-cdn.alpinelinux.org/alpine/v3.12/community" fonttools

# Install Noto Sans to comply with ReX guidelines
# See https://fonts.google.com/specimen/Noto+Sans
WORKDIR /usr/share/fonts/noto-sans
RUN  curl -fsSLo noto-sans.zip "https://fonts.google.com/download?family=Noto%20Sans" \
  && unzip -j noto-sans.zip '*.ttf' \
  && rm -f noto-sans.zip

# Install Noto Sans JP to comply with ReX guidelines
# See https://fonts.google.com/specimen/Noto+Sans+JP
WORKDIR /usr/share/fonts/noto-sans-jp
RUN  curl -fsSLo noto-sans-jp.zip "https://fonts.google.com/download?family=Noto%20Sans%20JP" \
  && unzip -j noto-sans-jp.zip '*.ttf' \
  && rm -f noto-sans-jp.zip

# Install FontAwesome
WORKDIR /usr/share/fonts/font-awesome
RUN  curl -fsSLo font-awesome.zip "https://use.fontawesome.com/releases/v5.15.1/fontawesome-free-5.15.1-web.zip" \
  && unzip -j font-awesome.zip '*/webfonts/*.ttf' \
  && rm -f font-awesome.zip

# Configure fonts
COPY fontconfig.xml /etc/fonts/conf.avail/95-rakuten.conf
RUN ln -s /etc/fonts/conf.avail/95-rakuten.conf /etc/fonts/conf.d/ && fc-cache -fv

# Configure home and user
WORKDIR /home/jetty
RUN useradd -M -r -g users jetty
RUN chown -R jetty:users .
USER jetty

# Copy default skin (beta, many things don't work well yet)
COPY plantuml.skin /home/jetty/

# Run
EXPOSE 8080
CMD [ "java", "-jar", "/home/jetty/start.jar" ]
