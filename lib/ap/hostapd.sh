#!/usr/bin/env bash

# ================================================================
# Configuration Section
# ================================================================
APServiceConfigDirectory=$FLUXIONWorkspacePath
# ================================================================

#if [ "$APServiceVersion" ]; then return 0; fi
#readonly APServiceVersion="1.0"

function ap_service_stop() {
  if [ "$APServicePID" ]; then
    kill $APServicePID &> $FLUXIONOutputDevice
  fi

  APServicePID=""
}

function ap_service_reset() {
  ap_service_stop

  # Reset MAC address to original.
  ip link set $APServiceInterface down
  sleep 0.25

  macchanger -p $APServiceInterface &> $FLUXIONOutputDevice
  sleep 0.25

  ip link set $APServiceInterface up
  sleep 0.25

  APServiceAccessInterface=""

  APServiceChannel=""
  APServiceMAC=""
  APServiceSSID=""
  APServiceInterfaceAddress=""
  APServiceInterface=""

}

function ap_service_route() {
  echo "APService: No custom routes for hostapd" > $FLUXIONOutputDevice
}

function ap_service_prep() {
  if [ ${#@} -lt 5 ]; then return 1; fi
  
  APServiceInterface=$1
  APServiceInterfaceAddress=$2
  APServiceSSID=$3
  APServiceMAC=$4
  APServiceChannel=$5
  
  ap_service_stop

  # Prepare the hostapd config file.
  country_code="$(iw reg get | awk 'FNR == 2 {print $2}' | cut -f 1 -d ":" 2> /dev/null)"
  [[ ! ${country_code} =~ ^[A-Z]{2}$ ]] && country_code="00"
  rm -rf "$APServiceConfigDirectory/$APServiceMAC-hostapd.conf" > /dev/null 2>&1
 
  echo "\
interface=$APServiceInterface
driver=nl80211
ssid=$APServiceSSID
channel=$APServiceChannel" \
  > "$APServiceConfigDirectory/$APServiceMAC-hostapd.conf"

  if [[ ${APServiceChannel} -gt 14 ]];then
      {
      echo -e "hw_mode=a"
      } >> "$APServiceConfigDirectory/$APServiceMAC-hostapd.conf"
  else
      {
      echo -e "hw_mode=g"
      } >> "$APServiceConfigDirectory/$APServiceMAC-hostapd.conf"
  fi
 
  if [[ "${country_code}" != "00" ]];then
      {
      echo -e "country_code=${country_code}"
      } >> "$APServiceConfigDirectory/$APServiceMAC-hostapd.conf"
  fi

  # Spoof virtual interface MAC address.
  ip link set $APServiceInterface down
  sleep 0.5

  macchanger --mac=$APServiceMAC $APServiceInterface &> $FLUXIONOutputDevice
  sleep 0.5

  ip link set $APServiceInterface up
  sleep 0.5

  # HostAPD sets the virtual interface mode
  # to master, which is supported by dhcpd.
  APServiceAccessInterface=$APServiceInterface
}

function ap_service_start() {
  ap_service_stop

  xterm $FLUXIONHoldXterm $TOP -bg "#000000" -fg "#FFFFFF" \
    -title "FLUXION AP Service [hostapd]" -e \
    hostapd "$APServiceConfigDirectory/$APServiceMAC-hostapd.conf" &
  local parentPID=$!

  # Wait till hostapd has started and its virtual interface is ready.
  while [ ! "$APServicePID" ]; do
    sleep 1
    APServicePID=$(pgrep -P $parentPID)
  done

  ap_service_route
}

# FLUXSCRIPT END
