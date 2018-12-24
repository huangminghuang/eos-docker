FROM huangminghuang/eos_builder

ARG branch=master
ARG symbol=SYS

RUN git clone --depth 1 -b $branch https://github.com/EOSIO/eos.git --recursive --shallow-submodules \
    && cd eos && echo "$branch:$(git rev-parse HEAD)" > /etc/eosio-version \
    && cmake -H. -Bbuild -GNinja -DCMAKE_BUILD_TYPE=Release -DWASM_ROOT=/opt/wasm \
       -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_MONGO_DB_PLUGIN=true -DCORE_SYMBOL_NAME=$symbol \
    && cmake --build build --target install