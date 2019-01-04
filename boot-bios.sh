#!/bin/bash

export config_dir=/usr/local/etc/eosio
config_ini=${config_dir}/config.ini

genesiskey=${GENESISKEY:-"EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV=KEY:5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"}
pri_genesiskey=${genesiskey##*=KEY:}
pub_genesiskey=${genesiskey%=KEY:*}
[[ "$pub_genesiskey" ==  "EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV" ]] || sed -i "s/EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV/$pub_genesiskey/" /usr/local/etc/eosio/genesis.json

cat << EOF >> $config_ini
plugin = eosio::chain_api_plugin
plugin = eosio::history_api_plugin
plugin = eosio::http_plugin
http-server-address = 0.0.0.0:8888 
http-validate-host = false
p2p-listen-endpoint = 0.0.0.0:9876 
signature-provider = ${genesiskey}
enable-stale-production = true
producer-name = eosio
EOF

function args_to_config() {
  while [[ $# -gt 0 ]]; do
    key=${1:2}
    value=true
    if [[ $2 != --* ]]; then
      value=$2 
      shift
    fi
    echo "$key = $value" >> $config_ini
    shift
  done
}

args_to_config $*

data_dir=${data_dir:-${HOME}/.local/share/eosio/nodeos/data}

set -x

## 'set -f' is used to disable filename expansion (globbing).
set -f
if [ ! -d "$data_dir" ]; then
  nodeos --genesis-json $config_dir/genesis.json --config-dir $config_dir |& tee log.txt &
  
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