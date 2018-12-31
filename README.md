# eos-docker - bootstrap an EOSIO Testnet using docker-compose

This project has two parts. First, it provide the Dockerfile to build the EOS docker image from scratch. The result docker image contains the binary from https://github.com/EOSIO/eos.git and the contracts from https://github.com/EOSIO/eosio-contracts.git. Seconds, it provides the docker compose file to
bootstrap an EOSIO Testnet with one nodeos process. It exposes the http port 8888 on the docker host for cleos to connect to. 

This is just a single machine solution. If you need to create a Testnet running on a cluster, please use the kubernetes solution from https://github.com/huangminghuang/eosio-testnet.git.

## Creating the docker image

Build the image from scatch may take a long time and requres enough CPU/RAM resources available to your docker daemon. You can just use the image `huangminghuang/eos` from DockerHub unless you need further customization.

The image building process is intentionally separated into two steps in order to speed up the build time for CI purpose. 

To build the image for the first time.
```bash
  docker build . -t $EOS_IMAGE --build-arg JOBS=2
```

If you encounter any internal compile error from g++, it is mostly because not enough RAM for your docker daemon. You may try `JOBS=1` to reduce the number of parallel jobs for compilation.

## Getting Started on local machine

Start a new Testnet with one nodeos process:
```bash
  export NODEOS_OPTIONS='---max-transaction-time 50000 --contracts-console --filter-on "*"' 
  docker-compose up
```

Stop the Testnet with the node gracefully shutted down:
```bash
  docker-compose stop
```

Start a previously stopped or killed Testnet:
```bash
  docker-compose start
```

Kill the Testnet:
```bash
  docker-compose kill
```

Shutdown the Testnet:
```bash
  docker-compose down
```

