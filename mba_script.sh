sudo apt-get install aptitude -y

echo "Adding macfanctld ppa (fan control daemon)."
sudo add-apt-repository ppa:mactel-support/ppa

wget http://ppa.launchpad.net/mactel-support/ppa/ubuntu/pool/main/m/macfanctld/macfanctld_0.6~mactel1ubuntu3~quantal_amd64.deb
wget https://launchpad.net/~poliva/+archive/lightum-mba/+files/lightum_2.3.1-ubuntu1_amd64.deb
wget https://launchpad.net/~poliva/+archive/lightum-mba/+files/lightum-indicator_0.7-ubuntu1_all.deb

sudo dpkg -i macfanctld_0.6~mactel1ubuntu3~quantal_amd64.deb
sudo dpkg -i lightum_2.3.1-ubuntu1_amd64.deb
sudo dpkg -i lightum-indicator_0.7-ubuntu1_all.deb


echo "Installing packages."
sudo aptitude update
sudo aptitude install lm-sensors applesmc-dkms libxss1

sudo modprobe applesmc

# The program lmsensors detects the sensors, however it does not know what they
# are yet. The module coretemp will allow lm-sensor to detect the others
# sensors, the rotation speed of the fan, and the GPU temperature.
sudo tee -a /etc/modules <<-EOF
	coretemp
	hid_apple
EOF

# make function keys behave normally and fn+ required for macro
sudo tee -a /etc/modprobe.d/hid_apple.conf <<-EOF
	options hid_apple fnmode=2
EOF
sudo modprobe coretemp hid_apple

# configure macfanctld
tee <<-EOF
	Configuring macfanctld to ignore some sensors. On my system three
	sensors gave bogus readings, i.e.,
	    TH0F: +249.2 C                                    
	    TH0J: +249.0 C                                    
	    TH0O: +249.0 C
	Run 'sensors' to see current values; run 'macfanctld -f' to
	obtain the list of sensors and their associated ID.
	Applying this exclude: 13 14 15.
EOF
sudo service macfanctld stop
sudo cp /etc/macfanctl.conf /etc/macfanctl.conf.$(date +%Y-%m-%d)
sudo sed -i "s/\(^exclude:\).*\$/\\1 13 14 15/" /etc/macfanctl.conf
sudo service macfanctld start

echo "Fixing post-hibernate hang."
sudo tee -a /etc/pm/config.d/macbookair_fix <<-EOF
	# The following brings back eth0 after suspend when using the apple usb-ethernet adapter.
	SUSPEND_MODULES="asix usbnet"
EOF

# no password after resume (like mac)
echo "Disable lock screen after resume."
gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'


# --- Boot ------------------------------------------------------

echo "Setting boot parm (better power usage)."
sudo cp /etc/default/grub /etc/default/grub.$(date +%Y-%m-%d)
SWAP=$(cat /etc/fstab |grep "# swap was on" |awk '{print $5}')
sudo sed -i "s:\(GRUB_CMDLINE_LINUX_DEFAULT=\).*\$:\\1\"quiet splash i915.i915_enable_rc6=1 resume=${SWAP}\":" /etc/default/grub
sudo update-grub

echo "Ensuring bcm5974 loads before usbhid (editing /etc/rc.local)."
# update /etc/rc.local to ensure bcm5974 is loaded BEFORE usbhid
sudo cp /etc/rc.local /etc/rc.local.$(date +%Y-%m-%d)
sudo sed -i '$i modprobe -r usbhid\nmodprobe -a bcm5974 usbhid' /etc/rc.local

echo "Configuring extra power management options."
wget -Nq http://pof.eslack.org/archives/files/mba42/99_macbookair || wget -Nq http://www.almostsure.com/mba42/99_macbookair
chmod 0755 99_macbookair
sudo mv 99_macbookair /etc/pm/power.d/99_macbookair
# disable bluetooth by default
sudo sed -i '$i /usr/sbin/rfkill block bluetooth' /etc/rc.local

# --- enable lightum
/usr/bin/lightum
/usr/bin/lightum-indicator &
gsettings set org.gnome.settings-daemon.plugins.power idle-dim-ac 'false'
gsettings set org.gnome.settings-daemon.plugins.power idle-dim-battery 'false'
