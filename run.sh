#!/bin/bash
set -x

export DEBIAN_FRONTEND=noninteractive
add-apt-repository ppa:bitcoin/bitcoin
apt-get update
apt-get install -y bitcoind jq git pv pbzip2
mkdir ~/.bitcoin

YYYYMMDD=$(date -u +%Y%m%d)

if [[ -e /vagrant/bitcoind-current.tbz2 ]]; then
    cd ~/.bitcoin
    tar xvjpf /vagrant/bitcoind-current.tbz2
fi

if [[ -e /vagrant/bootstrap-dist.dat ]]; then
    ln -s /vagrant/bootstrap-dist.dat ~/.bitcoin/bootstrap.dat
fi

cat > ~/.bitcoin/bitcoin.conf <<EOF
rpcuser=user
rpcpassword=password
addnode=bitcoin.coinprism.com
addnode=btcnode1.evolyn.net
addnode=InductiveSoul.US
addnode=faucet.bitcoin.st
addnode=ns2.dcscdn.com
addnode=btcnode1.bitgroup.cc
addnode=btcnode2.bitgroup.cc
addnode=btcnode3.bitgroup.cc
addnode=porgressbar.sk
EOF

bitcoind &
sleep 10
bitcoind getinfo

set +x 

CUR_HEIGHT=$( curl -s http://blockchain.info/latestblock | jq .height)

RUNNING=1
while [[ $RUNNING ]] ; do
    INFO=$(bitcoind getinfo)
    OURS=$( jq .blocks <<< "$INFO" )
    DIFF=$(( $CUR_HEIGHT - $OURS ))
    PCT=$( bc <<< "( $OURS / $CUR_HEIGHT ) * 100" )
    if [[ $DIFF -le 1 ]] ; then
        RUNNING=0
    fi
    echo $DIFF blocks left to download, $PCT done...
    echo "$INFO"
    sleep 1
done

bitcoind stop
cd ~/.bitcoin && rm bitcoin.conf bootstrap.dat debug.log peers.dat wallet.dat
cd ~/.bitcoin && tar -c . | pbzip2 | pv > /bitcoind-${YYYYMMDD}.tbz2
cd /var/tmp
git clone https://github.com/jgarzik/pynode.git
