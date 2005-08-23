#!/bin/bash
#######################################
# Sambaconf 4.0 for Kanotix
# by Andreas Weber
# 20.06.2004
# sambaconf@it-weber.com
# 
#######################################

function sudo_wrapper ()
{
if [ $UID != 0 ]; then
	if [ -d /KNOPPIX ]; then
		exec sudo "$0" "$@" ||exit 1
	else
		if [ -n "$DISPLAY" ]; then
			if [ -f /usr/bin/kdesu -o -f /usr/kde/3.2/bin/kdesu ]; then
				kdesu "$0" "$@" ||exit 1
			else
 				$DIALOG --title "$ProgName" --msgbox "You need to be root to run this Script." 10 35
			fi
		else
			echo -e "\n\nYou need to be root to run this Script.\n"
			exit 1
		fi
 exit 100
	fi
fi
}

function dialog_wrapper ()
{
LANG=C
export LANG
DIALOG=dialog
[ -n "$DISPLAY" ] && [ -x /usr/bin/Xdialog ] && DIALOG="Xdialog"
}

function check_smb ()
{
SMBINST=FALSE
if [ -f /etc/init.d/samba ]; then
	SMBINST=TRUE
	STARTSMB="/etc/init.d/samba start"
	STOPSMB="/etc/init.d/samba stop"
	RESTARTSMB="/etc/init.d/samba restart"
	RELOADSMB="/etc/init.d/samba reload"
fi

if [ "$SMBINST" = "FALSE" ]; then
	if [ -f /usr/sbin/smbd ]; then
		SMBINST=TRUE
		STARTSMB="/usr/sbin/smbd -D;/usr/sbin/nmbd -D"
		STOPSMB="killall -HUP smbd 2&>/dev/null;killall -HUP nmbd 2&>/dev/null"
		RESTARTSMB="$STOPSMB;$STARTSMB"
		RELOADSMB="$STOPSMB;$STARTSMB"
	else
		$DIALOG --title "ERROR" --msgbox "SAMBA not found.\n\nMaybe not installed." 20 50
		exit 1 
	fi
fi
}

function inputbox ()
{
 $DIALOG --stdout --no-cancel --title "$ProgName" --inputbox "\n$1\n\n" 20 "$2"
}
function passwordbox () 
{
 $DIALOG --stdout --no-cancel --title "$ProgName" --passwordbox "\n$1\n\n" 12 "$2"
}
function askyn ()
{
 $DIALOG --stdout --title "$ProgName" --yesno "\n$1\n" $2 $3
 echo $?
}

function splash ()
{
$DIALOG --title "$ProgName" --msgbox "\
$ProgName\n\nAuthor:Andreas Weber\nsambaconf@it-weber.com\n\n\n
This Script is experimental. There will be no warranty.\nUse it at you own Risk!\n\n\nPress OK to continue.\n\n " 20 50
}

function check_live ()
{
if [ -e /KNOPPIX/bin/ash ]; then
	MODE=CDROM
else
	MODE=HDD
fi
}

function get_plugin ()
{
if [ ! -f "/usr/lib/kde3/libkcm_kcmsambaconf.la" ]; then
if [ "$MODE" = "CDROM" ]; then
	echo "Continue without plugin."
else
	apt-get install kdenetwork-filesharing
fi
fi
}

function SMB_USER_CREATE ()
{
if [ "$MODE" = "CDROM" ]; then
SMB_USER=knoppix
WIN_USER=$(inputbox "What is the Windows Username of $SMB_USER\n\nexample: kanotix." 50)
if [ ! "$WIN_USER" ]; then
	$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
	S_USER=FAILED
	return
fi
SMB_PASS=$(passwordbox "Please type the Password for $SMB_USER:" 50)
if [ ! "$SMB_PASS" ]; then
	$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
	S_USER=FAILED
	return
fi
echo "$SMB_USER=$WIN_USER" >> $UMAP
smbpasswd -x "$SMB_USER" 
echo -e "$SMB_PASS\\n$SMB_PASS\\n" | smbpasswd -L -a "$SMB_USER" -s
$DIALOG --title "$ProgName" --msgbox "$SMB_USER created." 10 50
else
SMB_USER=$(inputbox "Type the Username to create a Samba User:\n\nexample: kanotix" 50)
if [ ! "$SMB_USER" ]; then
	$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
	S_USER=FAILED
	return
fi
cut -d: -f1 /etc/passwd |grep $SMB_USER
if [ "$?" != "0" ]; then
	$DIALOG --title "$
	ProgName" --msgbox "$SMB_USER is not a known Linux User.\nUser must be also exist as a Linux User." 10 50
	S_USER=FAILED
	return
fi
WIN_USER=$(inputbox "What is the Windows Username of $SMB_USER\n\nexample: kanotix" 50)
if [ ! "$WIN_USER" ]; then
	$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
	S_USER=FAILED
	return
fi
SMB_PASS=$(passwordbox "Please type the Password for $SMB_USER:" 50)
if [ ! "$SMB_PASS" ]; then
	$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
	S_USER=FAILED
	return
fi
echo "$SMB_USER=$WIN_USER" >> $UMAP
smbpasswd -x "$SMB_USER" 
echo -e "$SMB_PASS\\n$SMB_PASS\\n" | smbpasswd -L -a "$SMB_USER" -s
$DIALOG --title "$ProgName" --msgbox "$SMB_USER created." 10 50
fi

# create Administrator Account
SMB_PASS=$(passwordbox "Please type the Password for root / Administrator:" 50)
if [ ! "$SMB_PASS" ]; then
	$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
	S_USER=FAILED
	return
fi
echo "root=Administrator" >> $UMAP
smbpasswd -x root
echo -e "$SMB_PASS\\n$SMB_PASS\\n" | smbpasswd -L -a root -s
$DIALOG --title "$ProgName" --msgbox "root / Administrator Account created." 10 50

S_USER=OK
}
function workgroup ()
{
rm -f $CONF
rm -f $UMAP
rm -f $PMAP
echo
WKS=$(inputbox "Please type the Name of your Workgroup:\n\nexample: Kanotix-net." 50)
if [ ! "$WKS" ]; then
	$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
	S_WKS=FAILED
	return
fi

echo "[global]" > $CONF
echo "	workgroup = $WKS" >> $CONF
echo "	netbios name = $HOSTNAME" >> $CONF
echo "	server string = host %h Version %v for %I" >> $CONF
echo "	security = user" >> $CONF
echo "	encrypt passwords = yes" >> $CONF
echo "	map to guest = Bad User" >> $CONF
echo "	username map = $UMAP" >> $CONF
echo "	smb passwd file = $PMAP" >> $CONF
echo "	socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192" >> $CONF
echo "	character set = ISO8859-1" >> $CONF
echo "	printcap name = cups" >> $CONF
echo "	load printers = yes" >> $CONF
echo "	printing = cups" >> $CONF
echo "	guest ok = yes" >> $CONF
echo "	" >> $CONF

SMB_USER_CREATE
if [ "$S_USER" = "FAILED" ]; then
	SMB_USER_CREATE
fi

ASK=$(askyn "Would you like to share the Homedrives?\n\nThis Shares will only available for the Owner." 10 50)
if [ ! "$ASK" ]; then
	exit 1
fi
if [ "$ASK" = "0" ]; then
echo "[homes]" >> $CONF
echo "	comment = Home Directories" >> $CONF
echo "	writeable = yes" >> $CONF
echo "	browseable = no" >> $CONF
echo "	dos filetimes = true" >> $CONF
echo "	valid users = %S" >> $CONF
echo "	read-only = no" >> $CONF
echo "	" >> $CONF
fi

ASK=$(askyn "Would you like to share your Printers?" 10 50)
if [ ! "$ASK" ]; then
	exit 1
fi
if [ "$ASK" = "0" ]; then
	echo "[printers]" >> $CONF
	PUSER=$(inputbox "Please type the Userame of the Printer-Administrator:\n\nexample: Administrator or root." 50)
	if [ ! "$PUSER" ]; then
		$DIALOG --title "$ProgName" --msgbox "ERROR: Required field is blank." 10 50
		S_WKS=FAILED
		return
	fi
	echo "	printer admin = $PUSER" >> $CONF
	echo "	comment = ALL Printers" >> $CONF
	echo "	browsable = no" >> $CONF
	echo "	path = /var/tmp" >> $CONF
	echo "	printable = yes" >> $CONF
	ASK=$(askyn "Would you like to restrict the \nPrinters for known Users only?\n\nIf you answer no, all Users will have Access to your Printers." 15 50)
	if [ "$ASK" = "0" ]; then
		echo "	public = no" >> $CONF
	else
		echo "	public = yes" >> $CONF
	fi
	echo "	writable = no" >> $CONF
	echo "	create mode = 0700" >> $CONF
	echo "" >> $CONF
fi
$RESTARTSMB
if [ "$MODE" = "CDROM" ]; then
	$DIALOG --title "$ProgName" --msgbox "Basic Configuration written and Samba started." 10 50
else
	$DIALOG --title "$ProgName" --msgbox "Basic Configuration written and Samba started." 20 50
fi
S_WKS=OK
}

function smb_killall ()
{
$STOPSMB
ps -ae |grep smbd
if [ "$?" != "0" ]; then
	killall -HUP smbd 2&>/dev/null
	killall -HUP nmbd 2&>/dev/null
fi
}

function diff_config_start ()
{
/usr/sbin/nmbd -D --configfile=$CONF
/usr/sbin/smbd -D --configfile=$CONF
}

function smb_restart ()
{
$RESTARTSMB
}

# Here start's the Script
# Set ENV
ProgName="Sambaconf 4.0"
CONF=/etc/samba/smb.conf
UMAP=/etc/samba/smbusers
PMAP=/etc/samba/smbpasswd
TMPF=/tmp/smb.tmp

# Start the Function's
dialog_wrapper
sudo_wrapper
splash
check_live
check_smb
get_plugin
workgroup
if [ "$S_WKS" = "FAILED" ]; then
	workgroup
else	
	exit 0
fi







