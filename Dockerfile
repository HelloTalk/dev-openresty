FROM alpine:3.9

ARG RESTY_LUAROCKS_VERSION="3.2.1"
ARG RESTY_VERSION="1.11.2.2"
ARG RESTY_OPENSSL_VERSION="1.0.2j"
ARG RESTY_PCRE_VERSION="8.43"
ARG RESTY_J="48"
ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "
ARG RESTY_LUAJIT_OPTIONS="--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-pcre \
    --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl/include' \
    --with-ld-opt='-L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl/lib -Wl,-rpath,/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl/lib' \
    "

# Volume for temporary files
VOLUME ["/var/run/openresty"]

# for openresty
RUN apk add --no-cache --virtual .build-deps \
        build-base \
        coreutils \
        curl \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
        gd \
        geoip \
        libgcc \
        libxslt \
        zlib \
    && cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && cd openssl-${RESTY_OPENSSL_VERSION} \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.1" ] ; then \
        echo 'patching OpenSSL 1.1.1 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.1c-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.0" ] ; then \
        echo 'patching OpenSSL 1.1.0 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/ed328977028c3ec3033bc25873ee360056e247cd/patches/openssl-1.1.0j-parallel_build_fix.patch | patch -p1 \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.0d-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && ./config \
      no-threads shared zlib -g \
      enable-ssl3 enable-ssl3-method \
      --prefix=/usr/local/openresty/openssl \
      --libdir=lib \
      -Wl,-rpath,/usr/local/openresty/openssl/lib \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install_sw \
    && cd /tmp \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && cd /tmp/pcre-${RESTY_PCRE_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/pcre \
        --disable-cpp \
        --enable-jit \
        --enable-utf \
        --enable-unicode-properties \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && curl -fSL https://github.com/openresty/openresty/releases/download/v${RESTY_VERSION}/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && eval ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_LUAJIT_OPTIONS} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz openssl-${RESTY_OPENSSL_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
    && apk del .build-deps \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

# for luarocks
RUN apk add --no-cache --virtual .build-deps \
        perl-dev \
        bash \
        build-base \
        curl \
        linux-headers \
        make \
        outils-md5 \
        perl \
        unzip \
	gettext \
    && cd /tmp \
    && curl -fSL https://luarocks.github.io/luarocks/releases/luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && tar xzf luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${RESTY_LUAROCKS_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit-2.1.0-beta3 \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make build \
    && make install \
    && cd /tmp \
    && rm -rf luarocks-${RESTY_LUAROCKS_VERSION} luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk del .build-deps \
    && mv /tmp/envsubst /usr/local/bin/

ENV LUA_PATH="/usr/local/openresty/site/lualib/?.ljbc;/usr/local/openresty/site/lualib/?/init.ljbc;/usr/local/openresty/lualib/?.ljbc;/usr/local/openresty/lualib/?/init.ljbc;/usr/local/openresty/site/lualib/?.lua;/usr/local/openresty/site/lualib/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua"
ENV LUA_CPATH="/usr/local/openresty/site/lualib/?.so;/usr/local/openresty/lualib/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so"

# for APISIX
RUN apk add --no-cache --virtual .builddeps \
    coreutils \
    automake \
    autoconf \
    libtool \
    pkgconfig \
    cmake \
    git \
    protobuf-c \
    zlib-dev \
    libgcc \
    gcc \
    unzip \
    build-base \
    wget \
    && apk add --no-cache libgcc \
    libmaxminddb \
    libmaxminddb-dev \
    libmcrypt \
    libmcrypt-dev \
    && mkdir -p /usr/local/openresty/luajit/lib/lua/5.1/lib \
    && git clone https://github.com/BLHT/lpack.git \
    && cd lpack \
    && gcc lpack.c -fPIC -shared -o lpack.so -Wall -I/usr/local/openresty/luajit/include/luajit-2.1 -L/usr/local/openresty/luajit/lib/  -lluajit-5.1 \
    && cp lpack.so /usr/local/openresty/luajit/lib/lua/5.1/pack.so \
    && cd /tmp \
    && git clone  https://github.com/BLHT/lua-zlib.git \
    && cd lua-zlib \
    && make linux \
    && cp zlib.so /usr/local/openresty/luajit/lib/lua/5.1/ \
    && cd /tmp \
    && git clone https://github.com/BLHT/pbc.git \
    && cd pbc \
    && make \
    && cd binding/lua \
    && make \
    && cp protobuf.so /usr/local/openresty/luajit/lib/lua/5.1/ \
    && cd /tmp \
    && git clone https://github.com/BLHT/some-dep-libs.git \
    && cd some-dep-libs/lua-libs/libstatistic \
    && gcc  xstatistic.c Attr_API.c oi_shm.c lib_hash.c -fPIC -shared -o xstatistic.so -Wall -I/usr/local/openresty/luajit/include/luajit-2.1 -L/usr/local/openresty/luajit/lib/  -lluajit-5.1 \
    && cp -fr xstatistic.so /usr/local/openresty/luajit/lib/lua/5.1/lib \
    && cd /tmp/some-dep-libs/lua-libs/libteacrypto \
    && gcc xteacrypt.c -fPIC -shared -o xteacrypt.so -Wall -I/usr/local/openresty/luajit/include/luajit-2.1 -L/usr/local/openresty/luajit/lib/  -lluajit-5.1 \
    && cp xteacrypt.so /usr/local/openresty/luajit/lib/lua/5.1/lib \
    && cd /tmp/some-dep-libs/lua-libs/maxmind \
    && gcc maxminddb.c -fPIC -shared -o maxminddb.so -Wall -I/usr/local/include -I/usr/local/openresty/luajit/include/luajit-2.1 -L/usr/local/openresty/luajit/lib/ -L/usr/local/lib  -lluajit-5.1 -lmaxminddb \
    && cp maxminddb.so /usr/local/openresty/luajit/lib/lua/5.1/lib \
    && cd /tmp/ \
    && wget http://luarocks.org/releases/luarocks-3.2.1.tar.gz \
    && tar -zxvf luarocks-3.2.1.tar.gz \
    && cd luarocks-3.2.1 \
    && ./configure \
        --prefix=/usr/local/luarocks  \
        --with-lua=/usr/local/openresty/luajit \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && luarocks install lua-protobuf  --tree=/usr/local \
    && cd /tmp/	\
    && rm -rf * \
    && apk del .builddeps
 
WORKDIR /usr/local/openresty/nginx

EXPOSE 80

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
