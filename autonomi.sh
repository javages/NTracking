#!/usr/bin/env bash

CLIENT=0.91.2
NODE=0.106.2
FAUCET=165.232.45.224:8000
NODE_MANAGER=0.7.5
PEER="/ip4/144.126.234.162/udp/37284/quic-v1/p2p/12D3KooWFTMioLueKChk9rWEFNFGTH3zRQ6eTiGxjL2ss1wWgZ11"
# get from https://sn-testnet.s3.eu-west-2.amazonaws.com/network-contacts


#run with
# bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/autonomi.sh)

# first node port can edited in menu later
NODE_PORT_FIRST=12000
NUMBER_NODES=50
NUMBER_COINS=1
CPU_TARGET=70
DELAY_BETWEEN_NODES=121000

export NEWT_COLORS='
window=,white
border=black,white
textbox=black,white
button=black,white
'

############################################## select test net action

SELECTION=$(whiptail --title "Autonomi Network Testnet punchbow 1.1 " --radiolist \
"Testnet Actions                              " 20 70 10 \
"1" "Install & Start Nodes " OFF \
"2" "Upgrade Client to Latest" OFF \
"3" "Stop Nodes update upgrade & restart system!!  " OFF \
"4" "Get Test Coins" ON \
"5" "Upgrade Nodes" OFF \
"6" "Start Vdash" OFF \
"7" "Spare                        " OFF \
"8" "Spare   " OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
exit 0
fi

################################################################################################################ start or Upgrade Client & Node to Latest
if [[ "$SELECTION" == "1" ]]; then


NODE_TYPE=$(whiptail --title "Safe Network Testnet 1.1" --radiolist \
"Type of Nodes to start                              " 20 70 10 \
"1" "Node from home no port forwarding    " OFF \
"2" "Cloud based nodes with port forwarding   " ON 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
exit 0
fi

#install latest infux resources script from github
sudo rm /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin  https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh

##############################  close fire wall
yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))

NUMBER_NODES=$(whiptail --title "Number of Nodes to start" --inputbox "\nEnter number of nodes" 8 40 $NUMBER_NODES 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi


if [[ "$NODE_TYPE" == "2" ]]; then

NODE_PORT_FIRST=$(whiptail --title "Port Number of first Node" --inputbox "\nEnter Port Number of first Node" 8 40 $NODE_PORT_FIRST 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi
############################## open ports
sudo ufw allow $NODE_PORT_FIRST:$(($NODE_PORT_FIRST+$NUMBER_NODES-1))/udp comment 'safe nodes'
sleep 2

fi

############################## Stop Nodes and delete safe folder

yes y | sudo env "PATH=$PATH" safenode-manager reset

# sudo snap remove curl
# sudo apt install curl

# disable installing safe up for every run
#curl -sSL https://raw.githubusercontent.com/maidsafe/safeup/main/install.sh | bash
#source ~/.config/safe/env

rm -rf $HOME/.local/share/safe/node

safeup node-manager --version $NODE_MANAGER
safeup client --version "$CLIENT"

cargo install vdash

############################## start nodes

mkdir -p /tmp/influx-resources

if [[ "$NODE_TYPE" == "2" ]]; then
# for cloud instances
sudo env "PATH=$PATH" safenode-manager add --node-port "$NODE_PORT_FIRST"-$(($NODE_PORT_FIRST+$NUMBER_NODES-1))  --count "$NUMBER_NODES" --version "$NODE"

else
# for home nodes hole punching
sudo env "PATH=$PATH" safenode-manager add --home-network --count "$NUMBER_NODES" --version "$NODE"
fi

sudo env "PATH=$PATH" safenode-manager start --interval $DELAY_BETWEEN_NODES | tee /tmp/influx-resources/nodemanager_output & disown


######################################################################################################################## Upgrade Client to Latest
elif [[ "$SELECTION" == "2" ]]; then
############################## Stop client and delete safe folder

rm -rf $HOME/.local/share/safe/client

safeup client

safe wallet get-faucet "$FAUCET"

######################################################################################################################## Stop Nodes
elif [[ "$SELECTION" == "3" ]]; then

sudo pkill -e safe

for i in {1..100}
do
 sudo systemctl disable --now safenode$i
done

sudo rm /etc/systemd/system/safenode*
sudo systemctl daemon-reload

sudo rm -rf /var/safenode-manager
sudo rm -rf /var/log/safenode

sleep 2

############################## close fire wall

yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))
yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))
yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))

rm -rf ~/.local/share/ntracking/

rustup update
sudo apt update -y && sudo apt upgrade -y
sudo reboot


######################################################################################################################## Get Test Coins
elif [[ "$SELECTION" == "4" ]]; then
NUMBER_COINS=$(whiptail --title "Number of Coins" --inputbox "\nEnter number of Coins" 8 40 $NUMBER_COINS 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

for (( c=1; c<=$NUMBER_COINS; c++ ))
do
   safe wallet get-faucet "$FAUCET"
   sleep 1
done

######################################################################################################################### Upgrade Nodes
elif [[ "$SELECTION" == "5" ]]; then

sudo env "PATH=$PATH" safenode-manager upgrade --interval 11000  | tee -a /tmp/influx-resources/node_upgrade_report

######################################################################################################################### Start Vdash
elif [[ "$SELECTION" == "6" ]]; then
vdash --glob-path "/var/log/safenode/*/safenode.log"
######################################################################################################################### spare
elif [[ "$SELECTION" == "7" ]]; then

echo "spare 7"

######################################################################################################################### spare
elif [[ "$SELECTION" == "8" ]]; then

echo "spare 8"

fi
