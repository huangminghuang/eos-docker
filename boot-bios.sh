#!/bin/bash

genesiskey=${GENESISKEY:-"EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV=KEY:5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"}
pri_genesiskey=${genesiskey##*=KEY:}
pub_genesiskey=${genesiskey%=KEY:*}
[[ "$pub_genesiskey" ==  "EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV" ]] || sed -i "s/EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV/$$pub_genesiskey/" /usr/local/etc/eosio/genesis.json


ARGS="$ARGS --plugin eosio::chain_api_plugin --plugin eosio::history_api_plugin" 
ARGS="$ARGS --plugin eosio::http_plugin --http-server-address 0.0.0.0:8888 --http-validate-host false --p2p-listen-endpoint 0.0.0.0:9876"
ARGS="$ARGS --enable-stale-production --producer-name eosio"
ARGS="$ARGS --genesis-json /usr/local/etc/eosio/genesis.json"
ARGS="$ARGS --signature-provider ${genesiskey}"
ARGS="$ARGS --logconf /usr/local/etc/eosio/logging.json"

while [[ $# -gt 0 ]]; do
  case $1 in
    '*')
      ARGS="$ARGS '*'"
      shift ;;
    *)
      ARGS="$ARGS $1"
      shift ;;
  esac
done

data_dir=${data_dir:-${HOME}/.local/share/eosio/nodeos/data}

## 'set -f' is used to disable filename expansion (globbing).
set -f
if [ ! -d "$data_dir" ]; then
  nodeos $ARGS |& tee log.txt &
  
  # stop the bios node after it outputs "on_incoming_block"
  while sleep 10
  do
      if fgrep --quiet "on_incoming_block" log.txt
      then
        sleep 600
        pkill nodeos
        exit 0
      fi
  done
fi