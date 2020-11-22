#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

if [[ ! $1 == "" ]]; then nodeName=$1; else echo "ERROR - Usage: $0 <PoolNodeName>"; exit 2; fi

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#	cardanocli	Path to the cardano-cli executable
#	cardanonode	Path to the cardano-node executable
#	remoteServerXXX Settings for the KES/OpCert update via SCP
. "$(dirname "$0")"/00_common.sh

SCRIPTDIR=$(dirname "$0")

#--  STEP 1  --------------------------------------------
# Generate new KES Pair and a new OpCert for the coreNode
#--------------------------------------------------------
${SCRIPTDIR}/04c_genKESKeys.sh ${nodeName}

${SCRIPTDIR}/04d_genNodeOpCert.sh ${nodeName}




#--  STEP 2  -------------------------------------------------------------
# Copy the new files into the ./upload directory and give them fixed names
# So you don't have to edit the coreNode configuration, always the same
#-------------------------------------------------------------------------

#Get the latest file version number
latestKESnumber=$(cat ${nodeName}.kes.counter)

#Copy them to a new filename in the upload folder with fixed names
nodeBaseName="$(basename ${nodeName})"  #grab the basename of the given PoolNodeName

mkdir -p ./upload

rm -rf ./upload/*

cp ./${nodeName}.kes-expire.json ./upload/${nodeBaseName}.kes-expire.json            #Copy latest KES expire information to automate alerts from the coreNode if needed
cp ./${nodeName}.kes-${latestKESnumber}.skey ./upload/${nodeBaseName}.kes.skey       #Copy latest KES key over to fixed name nodeName.kes.skey
cp ./${nodeName}.node-${latestKESnumber}.opcert ./upload/${nodeBaseName}.node.opcert #Copy latest opcert over to fixed name nodeName.node.opcert
cp ./${nodeName}.vrf.skey ./upload/${nodeBaseName}.vrf.skey				 #Copy vrf key over to fixed name nodeName.vrf.skey, sure is sure :-)




#--  STEP 3  --------------------------------------------------------------------
# Upload the files from the ./upload directory to the coreNode via SCP connection
#
# You need to provide your remote connection settings in the 00_common.sh file!!!
# Make sure you can ssh into your remote server with ssh public/private keypairs
#--------------------------------------------------------------------------------

chmod 644 ./upload/${nodeBaseName}.kes-expire.json	#change from 400 to 644 so the key can be read from another user (maybe systemd) too on the coreNode
chmod 644 ./upload/${nodeBaseName}.kes.skey
chmod 644 ./upload/${nodeBaseName}.node.opcert
chmod 644 ./upload/${nodeBaseName}.vrf.skey

echo -e "\e[0mUploading new files now ...\e[90m"
#Upload them to the CoreNode Server
scp -P ${remoteServerSSHport} ./upload/${nodeBaseName}.* ${remoteServerUser}@${remoteServerAddr}:${remoteServerDestDir}
echo -e "\e[0mDONE.\e[90m\n"




#--  STEP 4  ---------------------------------------------------------
# Execute the core restart script on the coreNode to load the new keys
#
# This should be automated on the coreNode itself in the future to
# find a nice leaderslot free spot in the scheduler.
#---------------------------------------------------------------------

#Executing a coreNode restart on the server
echo -e "\e[0mInitiating coreNode restart ...\e[90m"
ssh -p ${remoteServerSSHport} -tq ${remoteServerUser}@${remoteServerAddr} ${remoteServerPostCommand}
echo -e "\e[0mDONE. coreNode should now run with the new Keys!"
echo




