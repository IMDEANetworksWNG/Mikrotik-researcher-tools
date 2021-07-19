# Researcher version of Openwrt for wAP 60G/LHGG-60ad/wAP 60Gx3 AP

**This is not a oficially supported openwrt fork, do not contact the openwrt maintainers for help. If you have any questions email me at: pablo.jimenezmateo@imdea.org**

Features:

* Comes patched with all the features from [LEDE-ad7200](https://github.com/seemoo-lab/lede-ad7200)
* Imported the wil6210.fw (version 5.2.0.18) with sector information by default compiled with [nexmon-arc](https://github.com/seemoo-lab/nexmon-arc)
* Mikrotik brd file from Mikrotik OS version 6.43.12
* iperf3 is installed by default

**NOTE:** You can download the prebuilt images and skip the "How to build from source" section, prebuilt images can be found [here.](https://github.com/IMDEANetworksWNG/Mikrotik-researcher-tools/releases)

### How to build from source

1. Get the files
    ```bash
    git@github.com:IMDEANetworksWNG/Mikrotik-researcher-tools.git
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
    # Single core
    make defconfig
    
    #Or for multicore
    make -j 8 defconfig
    ```
4. When the configuration asks:
    * In Target system, select Qualcomm Atheros IPQ40XX
    * In Target Profile, select MikroTik Wireless Wire Dish LHGG-60ad

5. The image will have 2 files:

    ```bash
    ./build_dir/target-arm_cortex-a7+neon-vfpv4_musl_eabi/linux-ipq40xx/tmp/openwrt-ipq40xx-mikrotik_lhgg-60ad-initramfs-fit-uImage.elf
    ./build_dir/target-arm_cortex-a7+neon-vfpv4_musl_eabi/linux-ipq40xx/tmp/openwrt-ipq40xx-mikrotik_lhgg-60ad-squashfs-sysupgrade.bin
    ```
6. Rename the first file to vmlinux and the second to sysupgrade.bin for the next steps.

### How to flash the image

**Note:** If you don't want to build the image, you can download both files from [here.](https://github.com/IMDEANetworksWNG/Mikrotik-researcher-tools/releases/)

**Note:** If you only use the initramfs image, it will be like a live CD, nothing will be modified on the device and the Mikrotik OS will be restored on reboot.

1. ssh into the device and set it to Etherboot

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
8. Reboot the Mikrotik device, you can do that through ssh with
    ```bash
    /system reboot
    ```
9. Wait for the process to finish (should take around 2 minutes), you can check with Wireshark
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

### How to start the AP and STA

1. In the STA

    ```bash
    wpa_supplicant -D nl80211  -i wlan0 -c /etc/wpa_supplicant.conf -B
    ```
2. In the AP

    ```bash
    hostapd -B /etc/hostapd.conf
    ```
To modify the SSID or password, modify both conf files.

### How to get AoA and ToF masurements

**Note:** For this example I am using the MAC 08:55:31:0a:d6:e0, please change the peer address accordingly.

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

    **AoA**
    ```
    # Example of AoA result
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

    **ToF**
    ```
    # Example of ToF measurement
    [ 1281.744417] wil6210 0000:01:00.0 wlan0: wil_ftm_evt_per_dest_res: [FTM] Measurement: 1663086492, 257349564, 266483712, 1674073524
    ```

    The values are the 4 timestamps (t1, t2, t3, t4) in picoseconds.
