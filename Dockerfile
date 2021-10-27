FROM ubuntu:20.10

ARG motoko_version=0.6.11
ARG motoko_base_rev=d2e1187e8d761bae03dc5fc8168e8dc07a788592

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt -yq update && \
    apt -yqq install --no-install-recommends wget ca-certificates tar git && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/dfinity/motoko/releases/download/${motoko_version}/motoko-linux64-${motoko_version}.tar.gz && tar xf motoko-linux64-${motoko_version}.tar.gz && rm *.tar.gz
RUN git clone https://github.com/dfinity/motoko-base && cd motoko-base && git reset --hard ${motoko_base_rev} && rm -rf .git && cd ..
COPY . .
RUN ./moc --package base motoko-base/src --idl src/Ledger.mo -o ledger.generated.did
RUN ./moc --package base motoko-base/src -c src/Ledger.mo -o ledger.wasm
