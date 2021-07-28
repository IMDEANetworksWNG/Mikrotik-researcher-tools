# Researcher version of Openwrt for wAP 60G/LHGG-60ad/wAP 60Gx3 AP

**This is not a oficially supported openwrt fork, do not contact the openwrt maintainers for help. If you have any questions email me at: pablo.jimenezmateo@imdea.org**

Features:

* MikroTik brd file from MikroTik OS version 6.43.12
* iperf3 is installed by default
* FTM collection is enabled by default
* CSI collection is enabled by default

**NOTE:** You can download the prebuilt images and skip the "How to build from source" section, prebuilt images can be found [here.](https://github.com/IMDEANetworksWNG/Mikrotik-researcher-tools/releases)

### How to build from source

1. Get the files
    ```bash
    git clone git@github.com:IMDEANetworksWNG/Mikrotik-researcher-tools.git
    cd Mikrotik-researcher-tools/
    ```
    
2. Update the feeds

    ```bash
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    ```

3. Copy the config file
    ```
    cp mikrotik.config .config
    ```

3. Build the system
    ```bash
    # Use the default config
    make defconfig
    
    # Build using multiple cores, 8 in this case
    make -j 8 
    ```
4. If the configuration asks (or you want to use your own configuration) choose:
    * In Target system, select Qualcomm Atheros IPQ40XX
    * In Target Profile, select MikroTik 60ad

5. The image will have 2 files:

    ```bash
    ./build_dir/target-arm_cortex-a7+neon-vfpv4_musl_eabi/linux-ipq40xx/tmp/openwrt-ipq40xx-mikrotik_mikrotik-60ad-initramfs-fit-uImage.elf
    ./build_dir/target-arm_cortex-a7+neon-vfpv4_musl_eabi/linux-ipq40xx/tmp/openwrt-ipq40xx-mikrotik_mikrotik-60ad-squashfs-sysupgrade.bin
    ```
6. Rename the first file to vmlinux and the second to sysupgrade.bin for the next steps.

### How to flash the image

**Note:** If you don't want to build the image, you can download both files from [here.](https://github.com/IMDEANetworksWNG/Mikrotik-researcher-tools/releases/)

**Note:** If you only use the initramfs image, it will be like a live CD, nothing will be modified on the device and the MikroTik OS will be restored on reboot.

1. ssh into the device and set it to Etherboot (Optionally you can skip this step, see step 8):

    ```bash
    ssh admin@192.168.88.2
    /system routerboard settings set boot-device=try-ethernet-once-then-nand
    ```
    
2. Install TFTP boot

    **NOTE:** [Extra info](https://wiki.mikrotik.com/wiki/Manual:Netinstall)
    ```bash
    sudo apt update; sudo apt install tftp-hpa tftpd-hpa
    sudo ufw allow tftp
    ```
3. Move the image to the tftboot folder and restart the server
    ```bash
    sudo mv vmlinux /var/lib/tftpboot
    sudo /etc/init.d/tftpd-hpa restart
    ```
4. Install DHCP server
    ```bash
    sudo apt install isc-dhcp-server
    ```
5. Append the following lines to the DHCP server config 
    
    **NOTE:** Change the MAC

    ```bash
    #File /etc/dhcp/dhcpd.conf
    
    default-lease-time 600;
    max-lease-time 7200;
    ddns-update-style none;
    authoritative;
    subnet 192.168.88.0 netmask 255.255.255.0 {
    range 192.168.88.2 192.168.88.2;
    option routers 192.168.88.3;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 192.168.88.3, 8.8.8.8;
    }
    
    
    host mikrotik {
      hardware ethernet cc:2d:e0:9c:e2:35; #IMPORTANT: Change this MAC by the one of your device
      fixed-address 192.168.88.3;
    }
    ```
6. Restart the DHCP server
    ```bash
    sudo systemctl restart isc-dhcp-server
    ```
7. Set your IP address to 192.168.88.2/24
8. Reboot the MikroTik device, you can do that through ssh with
    ```bash
    /system reboot
    ```

    **NOTE:** Alternatively if you skipped step 1, you can unplug the device, press the reset button next to the ethernet port with a pen and plug it again while maintaining the reset button. Keep the button pressed until you see the first BOOTP requests in WireShark.

9. Wait for the process to finish (should take around 2 minutes), you can check with Wireshark
    1. You should first see the BOOTP petitions
    ![BOOTP](repo_figures/bootp.png?raw=true "BOOTP")
    2. If the TFTP protocol has not started restart the DHCP server
    ```
    sudo systemctl restart isc-dhcp-server
    ```
    3. If everything works correctly you will see the TFTP petitions
    ![TFTP](repo_figures/tftp.png?raw=true "TFTP")
    4. Wait until they are done


10. You should be able to connect to the device on the IP 192.168.1.1 with user root and no password
11. Stop the DHCP server and the TFTP server to make your sysadmin happy
    ```bash
    sudo /etc/init.d/isc-dhcp-server stop
    sudo /etc/init.d/tftpd-hpa stop
    ```
    
### How to make the flash permanent

1. Once flashed with the initramfs upload the sysupgrade file

    ```bash
    scp sysupgrade.bin root@192.168.1.1:/tmp
    ```
2. Flash it

    ```bash
    /sbin/sysupgrade /tmp/sysupgrade.bin
    ```
3. Wait until ssh works again (around 5 minutes)

4. Now we need the correct wil6210.fw, this firmware is in charge of the antenna, download the package [all_packages-arm-6.40.9.zip](https://download.mikrotik.com/routeros/6.40.9/all_packages-arm-6.40.9.zip) from the official MikroTik webpage
5. Extract it
6. Now we need to extract everything in the wireless-6.40.9-arm.npk binary
    ```
    binwalk -e wireless-6.40.9-arm.npk
    ```
7. This will create a new folder
    ```
    cd _wireless-6.40.9-arm.npk.extracted/squashfs-root/lib/firmware/
    ```
8. Check the md5 hash of the wil6210-d0.fw, it should be the following

    ```
    ae5ef66644ea08811f1b6269662f12b3  wil6210-d0.fw
    ```
9. Upload it to the device

```
scp wil6210-d0.fw root@192.168.1.1:/lib/firmware
```

10. Restart the device and everythign should be working

### How to start the AP and STA

1. In the STA

    ```bash
    wpa_supplicant -D nl80211  -i wlan0 -c /etc/wpa_supplicant.conf -B
    ```
2. In the AP

    ```bash
    hostapd -B /etc/hostapd.conf
    ```
To modify the SSID or password, modify both conf files. You can also remove the -B option if you do not want them running on background.

### How to get AoA and ToF masurements

**Note:** For this example I am using the MAC 08:55:31:0a:d6:e0, please change the peer address accordingly. You can also check the scripts below for mor information.

1. Start a normal connection from STA to AP

2. From the STA issue any of the following commands:

    **ToF**
    
    ```bash
    echo -n -e '\x08\x55\x31\x0a\xd6\xe0' | iw dev wlan0 vendor recv 0x001374 0x81 -
    ```

    **AoA**
    
    ```bash
    echo -n -e '\x08\x55\x31\x0a\xd6\xe0' | iw dev wlan0 vendor recv 0x001374 0x93 -
    ```
3. You should be able to get the output from dmesg:

    **CSI**
    ```
    # Example of CSI result
    [   60.374532] [AOA] Measurement: 0,1579846557.489942,08:55:31:0a:d6:e0,2,1,2,0,128,620,260,41,402,638,785,509,45,470,52,38,204,999,205,371,337,590,793,256,298,925,562,524,482,606,717,59,137,580,627,912,383,29,41,38,36,29,68,27,17,40,33,58,99,33,41,22,18,27,44,47,30,44,18,46,53,45,23,38,49,27,30,38,12
    ```
    The values are:
    
    * Return code, should always be 0
    * Time of the measurement as measured by the driver
    * Peer MAC
    * Channel, should be 2
    * Measurement type, should be 1
    * Rf mask, should be 2
    * Measurement status, should be 0
    * Length
    * The 32 next values are the phase (value between 0 and 1024)
    * The 32 next values are the magnitude

    **FTM**
    ```
    # Example of FTM measurement
    [ 1281.744417] wil6210 0000:01:00.0 wlan0: wil_ftm_evt_per_dest_res: [FTM] Measurement: 1663086492, 257349564, 266483712, 1674073524
    ```

    The values are the 4 timestamps (t1, t2, t3, t4) in picoseconds.

### How to disable the firewall

The default firewall is [fw3](https://openwrt.org/docs/guide-user/firewall/overview) stop it using fw3 stop

### How to change the IP of the device

1. Open the file /etc/config/network

```
# File /etc/config/network
config interface 'lan'
        option type 'bridge'
        option ifname 'eth0'
        option proto 'static'
        option ipaddr '192.168.1.1'
        option netmask '255.255.255.0'
        option ip6assign '60'
```
2. Change the line "option ipaddr '192.168.1.1'" under "config interface 'lan'" to your desired IP address
3. Reboot

### How to use monitor mode
1. Make sure you have not started the experiment yet

2. SSH into the device
    ```bash
    ssh root@192.168.1.1
    ```
3. Set the monitor mode

    ```bash
    # In one line for copy-paste
    ifconfig wlan0 up; iw dev wlan2 set type monitor; iw dev wlan0 set freq 60480; ifconfig wlan0 down; ifconfig wlan0 up
    ```
4. Remove any pcap in tmp
    ```bash
    rm /tmp/*.pcap
    ```
    
5. Start the capture with the desired parameters
    ```bash
    tcpdump -i wlan0 -s150 -B 32000 -w /tmp/test.pcap
    ```
5. Start the experiments you want to capture
    
6. Once everything is captured just Ctrl+C and check if there have been captured packets

    ```bash
    #It should look something like this
    #Don't worry if there are dropped packets unless there are too many
    32557 packets captured
    32557 packets received by filter
    0 packets dropped by kernel 
    ```

7. Copy the pcap file from the router to your local pc

    ```bash
    scp root@192.168.1.1:/tmp/test.pcap .
    ```
8. Repeat steps 3-6 every time you take a new capture

**Important things**

* Always write your files to /tmp, there is more than 200Mb available there and you won't run o ut of space soon
* Apply filters where necessary, this will reduce the capture time

    ```bash
    # Example of not capturing UDP packets to save space
    tcpdump -i wlan0 -s150 -B 32000 -w /tmp/test.pcap not proto \\udp
    ```
* Play with the capture size
    You can set a capture size per packet, and unless you want everything you can save a lot of space, 150bytes seem enough to get all the headers
    
    ```bash
    tcpdump -i wlan0 -s150 -B 32000 -w /tmp/test.pcap
    ```
    
    If you want to capture the whole packet set the size parameter to 0    
    
    ```bash
    tcpdump -i wlan0 -s0 -B 32000 -w /tmp/test.pcap
    ```

### Example to capture 300 CSI measurements from a peer


**NOTE:** Change the "\xaa\xaa\xaa\xaa\xaa\xaa" string with your peer's MAC address

```
# Empty the data file
echo "" > /tmp/csi_measurements.txt

# Reset the interface
ip link set dev wlan0 down
ip link set dev wlan0 up

# Reset the supplicant
killall wpa_supplicant

# Connect 
wpa_supplicant -D nl80211  -i wlan0 -c /etc/wpa_supplicant.conf -B

# This will help to check if we cannot connect
i=0
connected=0

while true ; do  # Loop until connected

    connected=$(cat /sys/kernel/debug/ieee80211/phy0/wil6210/stations | grep connected | wc -l)
                                             
    if [[ $connected -eq 1 ]]; then
      break
    fi

    i=$((i+1))

    # Break after a certain number of measurements
    if [[ $i -eq 10 ]]; then
      echo "[AoA] We cannot connect after 10 seconds"
      echo "Unreachable" > /tmp/aoa_measurements.txt
      exit
    fi

    sleep 1
done

echo "[CSI] We are connected now"

# A counter
i=0

while true ; do  # Loop until interval has elapsed.

    connected=$(cat /sys/kernel/debug/ieee80211/phy0/wil6210/stations | grep connected | wc -l)

    # Get AoA
    echo -n -e '\xaa\xaa\xaa\xaa\xaa\xaa' | iw dev wlan0 vendor recv 0x001374 0x93 -

    # Save the measurement
    echo $(dmesg | tail -n1) >> /tmp/csi_measurements.txt

    i=$((i+1))

    # Break when no connected
    if [[ $connected -eq 0 ]]; then
      echo "[CSI] We got " $i "measurements" 
      break
    fi

    # Break after a certain number of measurements
    if [[ $i -eq 300 ]]; then
      echo "[CSI] We got 300 measurements"
      break
    fi

done
```

### Example to capture 10 FTM measurements from a peer

**NOTE:** Change the "\xaa\xaa\xaa\xaa\xaa\xaa" string with your peer's MAC address

```
# Empty the file
echo "" > /tmp/ftm_measurements.txt

# Total number of measurements
total_measurements=0
connected=0
total_retries=0

# Clear dmesg
dmesg -c > /dev/null 2>&1

while true; do

    killall wpa_supplicant

    ip link set dev wlan0 down; ip link set dev wlan0 up

    wpa_supplicant -D nl80211  -i wlan0 -c /etc/wpa_supplicant.conf -B

    retries=0

    while true ; do  # Loop until connected

        connected=$(cat /sys/kernel/debug/ieee80211/phy0/wil6210/stations | grep connected | wc -l)
                                                                       
        if [[ $connected -eq 1 ]]; then
          break
        fi

        retries=$((retries+1))
        sleep 1

        if [[ $retries -eq 10 ]]; then

            break
        fi
    done

    # Check again to escape from outer loop
    if [[ $retries -eq 10 ]]; then

        echo "There is no connection"
        echo "Unreachable" >> /tmp/ftm_measurements.txt
        break
    fi

    total_retries=$((total_retries+1))

    if [[ $total_retries -eq 10 ]]; then

        echo "There is no FTM for a long time"
        echo "Unreachable" >> /tmp/ftm_measurements.txt
        break
    fi

    if [[ $connected -eq 1 ]]; then
        echo "We are connected now"

        # ToF command
        echo -n -e '\xaa\xaa\xaa\xaa\xaa\xaa' | iw dev wlan0 vendor recv 0x001374 0x81 -

        # Check if there are any measurements
        num_measurements=$(dmesg | grep Measurement | wc -l )

        if [[ $num_measurements -gt 0 ]]; then
      
            # Save the measurements
            echo "$(dmesg -c | grep Measurement)" >> /tmp/ftm_measurements.txt

            # Increment the number of measurements
            total_measurements=$((total_measurements+num_measurements))

            echo $num_measurements" new measurements ("$total_measurements"/10)" 

            # If correct we decrement by one
            total_retries=$((total_retries-1))
        fi

        # Break after a certain number of measurements
        if [[ $total_measurements -ge 10 ]]; then
          echo "We got "$total_measurements" measurements total"
          break
        fi
    fi
done

killall wpa_supplicant
```
