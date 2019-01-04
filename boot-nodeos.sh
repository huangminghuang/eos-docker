#/bin/bash

host_id=${HOSTID:-${HOSTNAME}}
host_prefix=${host_id%-*} ## GET the substring before the character '-' in HOSTNAME
ordinal=${host_id##*-}    ## GET the substring after the character '-' in HOSTNAME
service_pattern=${SERVICE_PATTERN:-${host_prefix}-\{\}} # the service pattern should be in the form of <StatefulSet-Name>-{}.<ServiceName>

echo PRODUCERS=${PRODUCERS} NODES=${NODES}
num_producers=${PRODUCERS:-1}
num_nodes=${NODES:-1}

data_dir=${data_dir:-${HOME}/.local/share/eosio/nodeos/data}
[ ! -d $data_dir ] || data_files=$(ls -A $data_dir 2>/dev/null)
export config_dir=/usr/local/etc/eosio
config_ini=${config_dir}/config.ini

bios_url=http://${BIOS_ADDR}
bios_host=${BIOS_ADDR%:*}

wallet_host=127.0.0.1:8899
wdurl=http://${wallet_host}

genesiskey=${GENESIS_KEY:-"EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV=KEY:5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"}
pri_genesiskey=${genesiskey##*=KEY:}
pub_genesiskey=${genesiskey%=KEY:*}

[[ "$pub_genesiskey" ==  "EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV" ]] || sed -i "s/EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV/$$pub_genesiskey/" /usr/local/etc/eosio/genesis.json

ecmd="cleos --wallet-url ${wdurl} --url ${bios_url}"
wcmd="cleos --wallet-url ${wdurl} wallet"

function echoerr { echo "$@" 1>&2; }


function config_p2p_addresses {
  echo "plugin = eosio::net_plugin" >> $config_ini
  for ((id=0; id<$num_nodes ; id++)); do
    [[ $id == $ordinal ]] || echo "p2p-peer-address = ${service_pattern/\{\}/${id}}:9876" >> $config_ini
  done
}

function wait_wallet_ready() {
  for (( i=0 ; i<10; i++ )); do
    ! $wcmd list 2>/tmp/wallet.txt || [ -s /tmp/wallets.txt ] || break
    sleep 3
  done
}

function wait_bios_ready {
  for (( i=0 ; i<10; i++ )); do
    ! $ecmd get info || break
    sleep 3
  done
}

function setup_eosio {
  
  # we only setup the eosio account when this is the first node
  [[ $ordinal == 0 ]] || return 0
  
  $ecmd set contract eosio /usr/local/contracts eosio.bios.wasm eosio.bios.abi || return 0

  set +x
  # Create required system accounts
  readarray syskey <<< $(cleos create key --to-console)
  local pubsyskey=${syskey[1]#"Public key:"}
  local prisyskey=${syskey[0]#"Private key:"}
  
  $wcmd import -n ignition --private-key $prisyskey
  echo $wcmd import -n ignition --private-key 
  set -x
  $ecmd create account eosio eosio.bpay $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.msig $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.names $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.ram $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.ramfee $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.saving $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.stake $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.token $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.vpay $pubsyskey $pubsyskey
  $ecmd create account eosio eosio.wrap $pubsyskey $pubsyskey

  $ecmd set contract eosio.token /usr/local/contracts eosio.token.wasm eosio.token.abi
  $ecmd set contract eosio.msig  /usr/local/contracts eosio.msig.wasm eosio.msig.abi
  $ecmd set contract eosio.wrap  /usr/local/contracts eosio.wrap.wasm eosio.wrap.abi

  $ecmd push action eosio.token create '["eosio","10000000000.0000 SYS"]' -p eosio.token
  $ecmd push action eosio.token issue '["eosio","1000000000.0000 SYS","memo"]' -p eosio

  $ecmd set contract eosio /usr/local/contracts eosio.system.wasm eosio.system.abi
  $ecmd push action eosio init '{"version":"0","core":"4,SYS"}' --permission eosio@active
  
}


function setup_wallet {
  rm -rf ${HOME}/eosio-wallet
  keosd --http-server-address ${wallet_host} &
  wait_wallet_ready
  $wcmd create --to-console -n ignition
  
  keyfile=$config_dir/key.txt
  
  
  keys=($(echo "$PRODUCER_KEYS" | tr ',' '\n')) 
  prikey=${keys[$ordinal]}
  
  if [ -z "$prikey" ]; then
    # create a new key file if not existed
    [ -f "$keyfile" ] || cleos create key --file $keyfile

    readarray syskey < $keyfile
    prikey=$(echo ${syskey[0]#"Private key: "} | xargs) ## xargs is usd to remove leading and trailing whitespaces 
  fi
    
  pubkey=$($ecmd wallet import -n ignition --private-key $prikey | sed 's/[^:]*: //')  
  echo "signature-provider = ${pubkey}=KEY:${prikey}" >> $config_ini
  
  echo "plugin = eosio::producer_plugin" >> $config_ini
}

function config_producer_args {
  
  setup_wallet
  
  alphabets="abcdefghijklmnopqrstuv"
  for (( id=$ordinal; id<21; id+=$num_producers )); do
    producer_name="defproducer${alphabets:$id:1}"
    echo "producer-name = ${producer_name}" >> $config_ini
    node_producers="${node_producers} ${producer_name}"
  done
}

function setup_producer_account {

  [ -n "$node_producers" ] || return 0
  
  while ! $ecmd get account eosio | grep "SYS balances"; do
    sleep 3
  done

  for producer_name in $node_producers; do
    $ecmd system newaccount --transfer --stake-net "10000000.0000 SYS" --stake-cpu "10000000.0000 SYS"  --buy-ram "10000000.0000 SYS" eosio $producer_name $pubkey $pubkey || continue
    $ecmd system regproducer $producer_name $pubkey
    $ecmd system voteproducer prods $producer_name $producer_name
  done
}

_term() { 
  trap - SIGTERM && kill -- 0
  sleep 3
  exit 0
}

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

echo "blocks-dir = blocks" >> $config_ini

args_to_config $*

[[ $num_nodes > $num_producers ]] || num_nodes=num_producers
[[ $num_producers < $ordinal ]] || config_producer_args

set -ex

config_p2p_addresses

cat << EOF >> $config_ini
plugin = eosio::chain_api_plugin
plugin = eosio::history_api_plugin
plugin = eosio::http_plugin
http-server-address = 0.0.0.0:8888 
http-validate-host = false
p2p-listen-endpoint = 0.0.0.0:9876 
p2p-server-address = ${service_pattern/\{\}/${ordinal}}:9876
EOF


trap _term SIGTERM
# trap "echo caught SIGTERM; kill -- -0; sleep 3; exit 0" SIGTERM EXIT

if [ -d "$data_dir" ] ; then
  [[ $ordinal != 0 ]] || echo "enable-stale-production = true" >> $config_ini
else
  ## remove data_dir if it's a dirty restart
  rm -rf ${data_dir}
  set +x
  $wcmd import -n ignition --private-key $pri_genesiskey
  set -x
  wait_bios_ready
  setup_eosio
  setup_producer_account
  
  cat << EOF >> $config_ini
p2p-peer-address = ${bios_host}:9876
enable-stale-production = true
EOF
fi


pkill keosd || :

set -f #disable file name globing 
nodeos_wrapper.sh &
child=$!
! wait "$child" || exit 0

nodeos_wrapper.sh --replay-blockchain &
child=$!
! wait "$child" || exit 0

nodeos_wrapper.sh --hard-replay-blockchain &
child=$!
wait "$child"

