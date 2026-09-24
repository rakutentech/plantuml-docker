FROM alpine:3.21

ARG JETTY_VERSION=12.1.13
ARG PLANTUML_VERSION=1.2026.8

ENV FONTCONFIG_PATH=/etc/fonts/
ENV JAVA_HOME=/usr/lib/jvm/zulu21-ca
ENV JETTY_BASE=/home/jetty
ENV JETTY_HOME=/opt/jetty-home
ENV HOME=/home/jetty
ENV LANG=C.UTF-8
ENV MAVEN_OPTS=-Xmx2G
ENV PLANTUML_LIMIT_SIZE=16384
ENV PLANTUML_SECURITY_PROFILE=ALLOWLIST
ENV PATH="${JAVA_HOME}/bin:$PATH"

RUN apk --no-cache add \
  curl \
  fontconfig \
  fontconfig-dev \
  freetype \
  gd \
  ghostscript-fonts \
  graphviz \
  jq \
  make \
  ncurses ncurses-terminfo \
  readline \
  shadow \
  unzip \
  && apk --no-cache add -X "https://dl-cdn.alpinelinux.org/alpine/edge/testing" font-fira-code

# Install JRE
WORKDIR /etc/apk/keys
RUN  curl -fsSLO "https://cdn.azul.com/public_keys/alpine-signing@azul.com-5d5dc44c.rsa.pub" \
  && echo "https://repos.azul.com/zulu/alpine" >> /etc/apk/repositories \
  && apk --no-cache add zulu21-jre

# Install Jetty
WORKDIR /opt/jetty-home
RUN set -o pipefail && curl -fsSL "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz" | tar xzp --strip-components=1

# Initialize Jetty base with required EE11 modules
WORKDIR /home/jetty
RUN java -jar /opt/jetty-home/start.jar \
    --create-startd \
    --add-modules=server,http,ee11-deploy,ee11-annotations,ee11-jsp,ee11-jstl \
  && echo "jetty.httpConfig.uriCompliance=DEFAULT,AMBIGUOUS_EMPTY_SEGMENT" \
     >> /home/jetty/start.d/server.ini

# Install PlantUML
RUN curl -f#SLo /plantuml.war "https://github.com/plantuml/plantuml-server/releases/download/v${PLANTUML_VERSION}/plantuml-v${PLANTUML_VERSION}.war"

# Create Jetty context descriptor for PlantUML
RUN mkdir -p /home/jetty/webapps \
  && printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN" "https://jetty.org/configure_10_0.dtd">\n<Configure class="org.eclipse.jetty.ee11.webapp.WebAppContext">\n  <Set name="contextPath">/</Set>\n  <Set name="war">/plantuml.war</Set>\n</Configure>\n' \
     > /home/jetty/webapps/ROOT.xml

# Install Mulish as a free-to-use alternative to the internal Rakuten Sans font.
# See https://fonts.google.com/specimen/Mulish
WORKDIR /usr/share/fonts/rakuten-sans
RUN  apk --no-cache add --virtual fonttools py3-fonttools \
  && curl -fsSL "https://fonts.google.com/download/list?family=Mulish" \
     | sed '1d' \
     | jq -r '.manifest.fileRefs[] | select(.filename | startswith("static/")) | "\(.url) \(.filename | ltrimstr("static/"))"' \
     | while read -r url name; do curl -fsSLo "$name" "$url"; done \
  && echo "Decompiling fonts…" \
  && find . -name \*.ttf -print -exec ttx -q -i {} + \
  && echo "Renaming fonts…" \
  && find . -name \*.ttx -print -exec sed -E -i 's/Mulish/Rakuten Sans/g' {} \; \
  && echo "Recompiling fonts…" \
  && find . -name \*.ttx -print -exec ttx -q -f {} + \
  && apk del fonttools

# Install Noto Sans to comply with ReX guidelines
# See https://fonts.google.com/specimen/Noto+Sans
WORKDIR /usr/share/fonts/noto-sans
RUN  curl -fsSL "https://fonts.google.com/download/list?family=Noto%20Sans" \
     | sed '1d' \
     | jq -r '.manifest.fileRefs[] | select(.filename | startswith("static/")) | "\(.url) \(.filename | ltrimstr("static/"))"' \
     | while read -r url name; do curl -fsSLo "$name" "$url"; done

# Install Noto Sans JP to comply with ReX guidelines
# See https://fonts.google.com/specimen/Noto+Sans+JP
WORKDIR /usr/share/fonts/noto-sans-jp
RUN  curl -fsSL "https://fonts.google.com/download/list?family=Noto%20Sans%20JP" \
     | sed '1d' \
     | jq -r '.manifest.fileRefs[] | select(.filename | startswith("static/")) | "\(.url) \(.filename | ltrimstr("static/"))"' \
     | while read -r url name; do curl -fsSLo "$name" "$url"; done

# Install FontAwesome
WORKDIR /usr/share/fonts/font-awesome
RUN  curl -fsSLo font-awesome.zip "https://use.fontawesome.com/releases/v5.15.4/fontawesome-free-5.15.4-web.zip" \
  && unzip -j font-awesome.zip '*/webfonts/*.ttf' \
  && rm -f font-awesome.zip

# Configure fonts
COPY fontconfig.xml /etc/fonts/conf.avail/99-local.conf
RUN ln -s /etc/fonts/conf.avail/99-local.conf /etc/fonts/conf.d/ && fc-cache -rv

# Configure home and user
WORKDIR /home/jetty
RUN  groupadd -r -g 20001 jetty \
  && useradd -M --no-log-init -r -u 20001 -g jetty jetty \
  && chown -R jetty:jetty /home/jetty
USER jetty

# Copy default skin (beta, many things don't work well yet)
COPY plantuml.skin /home/jetty/

# Copy the library so it can be included as a file rather than a URL
COPY rakuten.pu /home/jetty/

# Run
EXPOSE 8080
CMD [ "java", "-Dplantuml.allowlist.path=/home/jetty", "-jar", "/opt/jetty-home/start.jar", "jetty.base=/home/jetty" ]
