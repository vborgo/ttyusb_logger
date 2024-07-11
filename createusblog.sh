#! /bin/sh

#USB name
USB_SERIAL_NAME=$1

if [ -z "$USB_SERIAL_NAME" ]; then
    echo "Usage: e.g. sudo bash createusblogservice.sh ttyUSB0"
    exit 1
fi

echo ${USB_SERIAL_NAME}

# Get USB serial id
USB_SERIAL_ID=$(sudo systemctl | grep tty-${USB_SERIAL_NAME} |  awk '{print $1}')
echo ${USB_SERIAL_ID}
SERVICE_FILE_NAME=serialdatalogger${USB_SERIAL_NAME}.service
echo ${SERVICE_FILE_NAME}
# Log folder location
USER_NAME=vitorborgo
GROUP_NAME=vitorborgo
echo ${USER_NAME}
LOG_FOLDER_LOCATION=/var/${USER_NAME}
echo ${LOG_FOLDER_LOCATION}

# Create the system user
if command id -u id -u ${USER_NAME} >/dev/null 2>&1 ; then
	sudo adduser --system --no-create-home --disabled-login --group ${USER_NAME}
	sudo adduser ${USER_NAME} sudo
	sudo usermod --append --groups dialout ${GROUP_NAME}
fi

# Add No password sudo priviledge for user
NO_PASS_PRIV="${USER_NAME} ALL=(ALL) NOPASSWD:ALL"
if sudo grep -Fxq "${NO_PASS_PRIV}" "/etc/sudoers"
then
    echo "user ${USER_NAME} has priviledges" 
else
    echo ${NO_PASS_PRIV} | sudo EDITOR='tee -a' visudo
    echo "added user priviledges to user"
fi

# Check python dependencies
if command -V pip >/dev/null 2>&1 ; then
    echo "pip found version: $(pip -V)"
else
    echo "pip not found"
    sudo -H pip install pyserial
fi

#Create folder for log files
sudo mkdir -p ${LOG_FOLDER_LOCATION}
sudo chown ${USER_NAME}:${GROUP_NAME} ${LOG_FOLDER_LOCATION}

# Create service file
sudo touch -a /tmp/${SERVICE_FILE_NAME}
sudo cat <<EOT >> /tmp/${SERVICE_FILE_NAME} 
[Unit]
Description=Serial Data Logging Service ${USB_SERIAL_NAME}
After=${USB_SERIAL_ID}
BindsTo=${USB_SERIAL_ID}

[Service]
Type=simple
GuessMainPID=no
KillMode=process
Environment=PYTHONIOENCODING=utf-8
ExecStart=sudo /usr/bin/grabserial -v -Q -T -d /dev/${USB_SERIAL_NAME} -b 115200 -o "${LOG_FOLDER_LOCATION}/%%Y%%m%%d_Log${USB_SERIAL_NAME}.log" -A
TimeoutSec=2
Restart=on-failure
RestartPreventExitStatus=2 3
RuntimeMaxSec=1d
StandardInput=null
StandardOutput=syslog
StandardError=syslog+console
SyslogIdentifier=GrabSerial
User=${USER_NAME}
Group=${GROUP_NAME}
SupplementaryGroups=dialout
PermissionsStartOnly=true
StartLimitBurst=1
StartLimitInterval=0

[Install]
WantedBy=${USB_SERIAL_ID}
WantedBy=multi-user.target
EOT

#Copy file to system folder
sudo cp /tmp/${SERVICE_FILE_NAME} /etc/systemd/system/
sudo rm -f /tmp/${SERVICE_FILE_NAME}

#Enable serive
sudo systemctl enable ${SERVICE_FILE_NAME}

#Start service
sudo systemctl start ${SERVICE_FILE_NAME}

#echo service status
sleep 2
echo $(sudo systemctl status ${SERVICE_FILE_NAME})
