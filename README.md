# Researcher version of Openwrt for wAP 60G

Features:

* Comes patched with all the features from [LEDE-ad7200](https://github.com/seemoo-lab/lede-ad7200)
* Imported the wil6210.fw (version 5.2.0.18) with sector information by default compiled with [nexmon-arc](https://github.com/seemoo-lab/nexmon-arc)
* Mikrotik brd file from Mirkotik OS version 6.43.12
* iperf3 is installed by default

### How to build from source

1. Get the files
    ```bash
    git@github.com:IMDEANetworksWNG/Mikrotik-researcher-tools.git
    cd openwrt/
    ```
    
2. Update the feeds

    ```bash
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    ```

3. Build the system
    ```bash
    # Single core
    make
    
    #Or for multicore
    make -j 8
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

**Note:** If you don't want to build the image, you can download both files from [here](https://github.com/IMDEANetworksWNG/Mikrotik-researcher-tools/releases/tag/latest)

**Note:** If you only use the initramfs image, it will be like a live CD, nothing will be modified on the device and the Mikrotik OS will be restored on reboot.

1. ssh into the device and put it in Etherboot

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
5. Append the following lines on the DHCP server config 
    
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
    /sbin/sysupgrade sysupgrade.bin
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

