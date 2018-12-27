FROM gcr.io/oci-grandeos/eos-build-cache AS builder
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
    && apt-get install -y libssl1.1 libicu60 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/bin/cleos /usr/local/bin/cleos
COPY --from=builder /usr/local/bin/keosd /usr/local/bin/keosd
COPY --from=builder /usr/local/bin/nodeos /usr/local/bin/nodeos
COPY --from=builder /usr/local/bin/eosio-blocklog /usr/local/bin/eosio-blocklog
COPY --from=builder /usr/local/share/licenses /usr/local/share/licenses
COPY --from=builder /contracts /usr/local/contracts
