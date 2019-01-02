ARG EOS_BUILDER=huangminghuang/eos_builder

FROM $EOS_BUILDER AS eos-cache
ARG EOS_VERSION=v1.5.2
ARG JOBS=2
RUN git clone --depth 1 -b $EOS_VERSION --single-branch https://github.com/EOSIO/eos.git --recursive \
    && cd eos \
    && cmake -H. -Bbuild -G Ninja -DCMAKE_BUILD_TYPE=Release -DWASM_ROOT=/opt/wasm -DCORE_SYMBOL_NAME=SYS \
      -DCMAKE_INSTALL_PREFIX=/usr/local  -DBUILD_MONGO_DB_PLUGIN=true \
      -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache  \
    && cmake --build build --target install -- -j $JOBS \
    && cd .. \
    && rm -rf eos

FROM huangminghuang/eos_builder AS contract-builder
ARG CONTRACTS_VERSION=v1.5.1
RUN curl -sLO https://storage.googleapis.com/oci-grandeos/eosio_cdt-1.4.1-ubuntu-18.04.deb \
    && dpkg -i eosio_cdt-1.4.1-ubuntu-18.04.deb
RUN git clone --depth 1 -b $CONTRACTS_VERSION --single-branch https://github.com/EOSIO/eosio.contracts.git --recursive
RUN cd eosio.contracts \
    && sed -i 's/include(Unit/#include(Unit/' CMakeLists.txt \
    && cmake -H. -Bbuild -GNinja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --target all \
    && mkdir -p /contracts \
    && find build -name "*.wasm" -o -name "*.abi" | xargs cp -t /contracts/
    
FROM ubuntu:18.04
RUN apt-get update \
    && apt-get install -y libssl1.1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=eos-cache /usr/local/bin/cleos /usr/local/bin/cleos
COPY --from=eos-cache /usr/local/bin/keosd /usr/local/bin/keosd
COPY --from=eos-cache /usr/local/bin/nodeos /usr/local/bin/nodeos
COPY --from=eos-cache /usr/local/bin/eosio-blocklog /usr/local/bin/eosio-blocklog
COPY --from=eos-cache /usr/local/share/licenses /usr/local/share/licenses
COPY --from=contract-builder /contracts /usr/local/contracts
COPY *.json /usr/local/etc/eosio/
COPY *.sh /usr/local/bin/
COPY docker-compose*.yaml /
RUN chmod +x /usr/local/bin/*.sh