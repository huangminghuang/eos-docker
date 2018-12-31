#!/bin/bash

genesiskey=${GENESISKEY:-"EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV=KEY:5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"}
pri_genesiskey=${genesiskey##*=KEY:}
pub_genesiskey=${genesiskey%=KEY:*}
[[ "$pub_genesiskey" ==  "EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV" ]] || sed -i "s/EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV/$$pub_genesiskey/" /usr/local/etc/eosio/genesis.json


ARGS="$ARGS --plugin eosio::chain_api_plugin --plugin eosio::history_api_plugin" 
ARGS="$ARGS --plugin eosio::http_plugin --http-server-address 0.0.0.0:8888 --http-validate-host false --p2p-listen-endpoint 0.0.0.0:9876 --p2p-server-address bios:9876"
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

set -e
set -x
[ -d "$data_dir" ] || exec /usr/local/bin/nodeos_wrapper.sh $ARGS
