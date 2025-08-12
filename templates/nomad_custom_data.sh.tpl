#!/usr/bin/env bash
set -euo pipefail

LOGFILE="/var/log/nomad-cloud-init.log"
SYSTEMD_DIR="${systemd_dir}"
NOMAD_DIR_CONFIG="${nomad_dir_config}"
NOMAD_CONFIG_PATH="$NOMAD_DIR_CONFIG/nomad.hcl"
NOMAD_DIR_TLS="${nomad_dir_config}/tls"
NOMAD_DIR_DATA="${nomad_dir_home}/data"
NOMAD_DIR_LICENSE="${nomad_dir_home}/license"
NOMAD_DIR_ALLOC_MOUNTS="${nomad_dir_home}/alloc_mounts"
NOMAD_LICENSE_PATH="$NOMAD_DIR_LICENSE/license.hclic"
NOMAD_DIR_LOGS="/var/log/nomad"
NOMAD_DIR_BIN="${nomad_dir_bin}"
CNI_DIR_BIN="${cni_dir_bin}"
NOMAD_USER="nomad"
NOMAD_GROUP="nomad"
PRODUCT="nomad"
NOMAD_VERSION="${nomad_version}"
VERSION=$NOMAD_VERSION

REQUIRED_PACKAGES="curl jq unzip"
ADDITIONAL_PACKAGES="${additional_package_names}"

function log {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_entry="$timestamp [$level] - $message"

    echo "$log_entry" | tee -a "$LOGFILE"
}

function detect_os_distro {
    local OS_DISTRO_NAME=$(grep "^NAME=" /etc/os-release | cut -d"\"" -f2)
    local OS_DISTRO_DETECTED

    case "$OS_DISTRO_NAME" in
    "Ubuntu"*)
        OS_DISTRO_DETECTED="ubuntu"
        ;;
    "CentOS"*)
        OS_DISTRO_DETECTED="centos"
        ;;
    "Red Hat"*)
        OS_DISTRO_DETECTED="rhel"
        ;;
    "Amazon Linux"*)
        OS_DISTRO_DETECTED="al2023"
        ;;
    *)
        log "ERROR" "'$OS_DISTRO_NAME' is not a supported Linux OS distro for this NOMAD module."
        exit_script 1
        ;;
    esac

    echo "$OS_DISTRO_DETECTED"
}

function detect_architecture {
  local ARCHITECTURE=""
  local OS_ARCH_DETECTED=$(uname -m)

  case "$OS_ARCH_DETECTED" in
    "x86_64"*)
      ARCHITECTURE="linux_amd64"
      ;;
    "aarch64"*)
      ARCHITECTURE="linux_arm64"
      ;;
		"arm"*)
      ARCHITECTURE="linux_arm"
			;;
    *)
      log "ERROR" "Unsupported architecture detected: '$OS_ARCH_DETECTED'. "
		  exit_script 1
  esac

  echo "$ARCHITECTURE"

}

# https://cloud.google.com/sdk/docs/install-sdk#linux
function install_gcloud_sdk () {
  if [[ -n "$(command -v gcloud)" ]]; then
    echo "INFO: Detected gcloud SDK is already installed."
  else
    echo "INFO: Attempting to install gcloud SDK."
    if [[ -n "$(command -v python)" ]]; then
      curl -sO https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz -o google-cloud-sdk.tar.gz
      tar xzf google-cloud-sdk.tar.gz
      ./google-cloud-sdk/install.sh --quiet
    else
      echo "ERROR: gcloud SDK requires Python but it was not detected on system."
      exit_script 5
    fi
  fi
}

function prepare_disk() {
  local device_name="$1"
  log "DEBUG" "prepare_disk - device_name; $${device_name}"

  local device_mountpoint="$2"
  log "DEBUG" "prepare_disk - device_mountpoint; $${device_mountpoint}"

  local device_label="$3"
  log "DEBUG" "prepare_disk - device_label; $${device_label}"

  local device_id=$(readlink -f /dev/disk/by-id/$${device_name})
  log "DEBUG" "prepare_disk - device_id; $${device_id}"

  mkdir -p  $device_mountpoint

  # https://cloud.google.com/compute/docs/disks/optimizing-pd-performance#os-changes
  # exclude quotes on device_label or formatting will fail
  mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 -L $device_label $${device_id}

  echo "LABEL=$device_label $device_mountpoint ext4 defaults 0 2" >> /etc/fstab

  mount -a
}

function install_prereqs {
    local OS_DISTRO="$1"
    log "INFO" "Installing required packages..."

    if [[ "$OS_DISTRO" == "ubuntu" ]]; then
        sleep 60
        apt-get update -y
        apt-get install -y $REQUIRED_PACKAGES $ADDITIONAL_PACKAGES
    elif [[ "$OS_DISTRO" == "rhel" ]]; then
        yum install -y $REQUIRED_PACKAGES $ADDITIONAL_PACKAGES
    elif [[ "$OS_DISTRO" == "amzn2023" ]]; then
        yum install -y $REQUIRED_PACKAGES $ADDITIONAL_PACKAGES
    else
        log "ERROR" "Unsupported OS distro '$OS_DISTRO'. Exiting."
        exit_script 1
    fi
}

# scrape_vm_info gets the required information needed from the cloud's API
function scrape_vm_info {
  # https://cloud.google.com/compute/docs/metadata/default-metadata-values
  #AVAILABILITY_ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/attributes/google-compute-default-region?recursive=true" -H "Metadata-Flavor: Google" )
  AVAILABILITY_ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google"  | cut -d'/' -f4)
  INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
}

# For Nomad there are a number of supported runtimes, including Exec, Docker, Podman, raw_exec, and more. This function should be modified
# to install the runtime that is appropriate for your environment. By default the no runtimes will be enabled.
function install_runtime {
    log "INFO" "Installing a runtime..."
#   # EXAMPLE: Uncomment to install docker runtime in ubuntu
#    if [[ "$OS_DISTRO" == "ubuntu" ]]; then
#        apt-get install -y docker.io
#        usermod -G docker -a $NOMAD_USER
#    fi
    log "INFO" "Done installing runtime."
}

function fetch_nomad_license {
  log "INFO" "Retrieving Nomad license '${nomad_license_sm_secret_name}' from Secret Manager."
  gcloud secrets versions access latest --secret=${nomad_license_sm_secret_name} > $NOMAD_DIR_LICENSE/license.hclic

  log "INFO" "Setting license file permissions and ownership"
  sudo chown $NOMAD_USER:$NOMAD_GROUP $NOMAD_DIR_LICENSE/license.hclic
  sudo chmod 660 $NOMAD_DIR_LICENSE/license.hclic
}

function fetch_tls_certificates {
  log "INFO" "Retrieving TLS certificate '${nomad_tls_cert_sm_secret_name}' from Secret Manager."
  gcloud secrets versions access latest --secret=${nomad_tls_cert_sm_secret_name} | base64 -d > $NOMAD_DIR_TLS/cert.pem

  log "INFO" "Retrieving TLS private key '${nomad_tls_privkey_sm_secret_name}' from Secret Manager."
  gcloud secrets versions access latest --secret=${nomad_tls_privkey_sm_secret_name} | base64 -d > $NOMAD_DIR_TLS/key.pem

%{ if nomad_tls_ca_bundle_sm_secret_name != "NONE" ~}
  log "INFO" "Retrieving CA certificate '${nomad_tls_ca_bundle_sm_secret_name}' from Secret Manager."
  gcloud secrets versions access latest --secret=${nomad_tls_ca_bundle_sm_secret_name} | base64 -d > $NOMAD_DIR_TLS/ca.pem
%{ endif ~}

  log "INFO" "Setting certificate file permissions and ownership"
  sudo chown $NOMAD_USER:$NOMAD_GROUP $NOMAD_DIR_TLS/*
  sudo chmod 400 $NOMAD_DIR_TLS/*
}

function fetch_nomad_gossip_key {
  log "INFO" "Retrieving Nomad gossip key '${nomad_gossip_key_secret_name}' from Secret Manager."
  GOSSIP_ENCRYPTION_KEY=$(gcloud secrets versions access latest --secret=${nomad_gossip_key_secret_name})
}

# user_create creates a dedicated linux user for Nomad
function user_group_create {
    log "INFO" "Creating Nomad user and group..."

    # Create the dedicated as a system group
    sudo groupadd --system $NOMAD_GROUP

    # Create a dedicated user as a system user
    sudo useradd --system --no-create-home -d $NOMAD_DIR_CONFIG -g $NOMAD_GROUP $NOMAD_USER

    log "INFO" "Done creating Nomad user and group"
}

function directory_create {
    log "INFO" "Creating necessary directories..."

    # Define all directories needed as an array
    directories=($NOMAD_DIR_CONFIG $NOMAD_DIR_DATA $NOMAD_DIR_TLS $NOMAD_DIR_LICENSE $NOMAD_DIR_LOGS $CNI_DIR_BIN $NOMAD_DIR_ALLOC_MOUNTS)

    # Loop through each item in the array; create the directory and configure permissions
    for directory in "$${directories[@]}"; do
        log "INFO" "Creating $directory"

        mkdir -p $directory
        sudo chown $NOMAD_USER:$NOMAD_GROUP $directory
        sudo chmod 750 $directory
    done

    log "INFO" "Done creating necessary directories."
}

function checksum_verify {
  local OS_ARCH="$1"

  # https://www.hashicorp.com/en/trust/security
  # checksum_verify downloads the $$PRODUCT binary and verifies its integrity
  log "INFO" "Verifying the integrity of the $${PRODUCT} binary."
  export GNUPGHOME=./.gnupg
  log "INFO" "Importing HashiCorp GPG key."
  sudo curl -s https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import

	log "INFO" "Downloading $${PRODUCT} binary"
  sudo curl -Os https://releases.hashicorp.com/"$${PRODUCT}"/"$${VERSION}"/"$${PRODUCT}"_"$${VERSION}"_"$${OS_ARCH}".zip
	log "INFO" "Downloading Vault Enterprise binary checksum files"
  sudo curl -Os https://releases.hashicorp.com/"$${PRODUCT}"/"$${VERSION}"/"$${PRODUCT}"_"$${VERSION}"_SHA256SUMS
	log "INFO" "Downloading Vault Enterprise binary checksum signature file"
  sudo curl -Os https://releases.hashicorp.com/"$${PRODUCT}"/"$${VERSION}"/"$${PRODUCT}"_"$${VERSION}"_SHA256SUMS.sig
  log "INFO" "Verifying the signature file is untampered."
  gpg --verify "$${PRODUCT}"_"$${VERSION}"_SHA256SUMS.sig "$${PRODUCT}"_"$${VERSION}"_SHA256SUMS
	if [[ $? -ne 0 ]]; then
		log "ERROR" "Gpg verification failed for SHA256SUMS."
		exit_script 1
	fi
  if [ -x "$(command -v sha256sum)" ]; then
		log "INFO" "Using sha256sum to verify the checksum of the $${PRODUCT} binary."
		sha256sum -c "$${PRODUCT}"_"$${VERSION}"_SHA256SUMS --ignore-missing
	else
		log "INFO" "Using shasum to verify the checksum of the $${PRODUCT} binary."
		shasum -a 256 -c "$${PRODUCT}"_"$${VERSION}"_SHA256SUMS --ignore-missing
	fi
	if [[ $? -ne 0 ]]; then
		log "ERROR" "Checksum verification failed for the $${PRODUCT} binary."
		exit_script 1
	fi

	log "INFO" "Checksum verification passed for the $${PRODUCT} binary."

	log "INFO" "Removing the downloaded files to clean up"
	sudo rm -f "$${PRODUCT}"_"$${VERSION}"_SHA256SUMS "$${PRODUCT}"_"$${VERSION}"_SHA256SUMS.sig

}

# install_nomad_binary downloads the Nomad binary and puts it in dedicated bin directory
function install_nomad_binary {
	local OS_ARCH="$1"

  log "INFO" "Deploying Nomad Enterprise binary to $NOMAD_DIR_BIN unzip and set permissions"
	sudo unzip "$${PRODUCT}"_"$${NOMAD_VERSION}"_"$${OS_ARCH}".zip  nomad -d $NOMAD_DIR_BIN
	sudo unzip "$${PRODUCT}"_"$${NOMAD_VERSION}"_"$${OS_ARCH}".zip -x nomad -d $NOMAD_DIR_LICENSE
	sudo rm -f "$${PRODUCT}"_"$${NOMAD_VERSION}"_"$${OS_ARCH}".zip

	# Set the permissions for the nomad binary
	sudo chmod 0755 $NOMAD_DIR_BIN/nomad
	sudo chown $NOMAD_USER:$NOMAD_GROUP $NOMAD_DIR_BIN/nomad

	# Create a symlink to the Nomad binary in /usr/local/bin
	sudo ln -sf $NOMAD_DIR_BIN/nomad /usr/local/bin/nomad

	log "INFO" "Nomad binary installed successfully at $NOMAD_DIR_BIN/nomad"
}

function install_cni_plugins {
    log "INFO" "Installing CNI plugins..."

    # Download the CNI plugins
    sudo curl -Lso $CNI_DIR_BIN/cni-plugins.tgz "${cni_install_url}"

    # Untar the CNI plugins
    tar -C $CNI_DIR_BIN -xzf $CNI_DIR_BIN/cni-plugins.tgz
}

function configure_sysctl {
    log "INFO" "Configuring sysctl settings..."

    # Configure sysctl settings for Nomad
    tee -a /etc/sysctl.d/bridge.conf <<-EOF
    net.bridge.bridge-nf-call-arptables = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
EOF
}

function generate_nomad_config {
  log "INFO" "Generating $NOMAD_CONFIG_PATH file."


  cat >$NOMAD_CONFIG_PATH <<EOF

# Full configuration options can be found at https://developer.hashicorp.com/nomad/docs/configuration

%{ if nomad_acl_enabled }
acl {
  enabled = true
}%{ endif }

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

datacenter = "${nomad_datacenter}"
region     = "${nomad_region}"

# leave_on_interrupt = true
# leave_on_terminate = true

enable_syslog   = true
syslog_facility = "daemon"

%{ if nomad_server }
server {
  enabled          = true

  bootstrap_expect = "${nomad_nodes}"
  license_path     = "$NOMAD_LICENSE_PATH"
  encrypt          = "$GOSSIP_ENCRYPTION_KEY"
  redundancy_zone  = "$AVAILABILITY_ZONE"

  server_join {
    retry_join = ["provider=gce zone_pattern=${auto_join_zone_pattern} tag_value=${auto_join_tag_value}"]
  }
}

%{ if autopilot_health_enabled }
autopilot {
    cleanup_dead_servers      = true
    last_contact_threshold    = "200ms"
    max_trailing_logs         = 250
    server_stabilization_time = "10s"
    enable_redundancy_zones   = true
    disable_upgrade_migration = false
    enable_custom_upgrades    = false
}
%{ endif }
%{ endif }

%{ if nomad_tls_enabled }
tls {
  http      = true
  rpc       = true
  cert_file = "$NOMAD_DIR_TLS/cert.pem"
  key_file  = "$NOMAD_DIR_TLS/key.pem"
%{ if nomad_tls_ca_bundle_sm_secret_name != null ~}
  ca_file   = "$NOMAD_DIR_TLS/ca.pem"
%{ endif ~}
  verify_server_hostname = true
  verify_https_client    = false
}
%{ endif }

%{ if nomad_client }
client {
  enabled = true
%{ if nomad_upstream_servers != null ~}
servers = [
%{ for addr in formatlist("%s",nomad_upstream_servers) ~}
   "${addr}",
%{ endfor ~}
]
%{ else }
  server_join {
    retry_join = ["provider=gce zone_pattern=${auto_join_zone_pattern} tag_value=${auto_join_tag_value}"]
  }
%{ endif }
}
%{ endif }

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

ui {
  enabled = ${ nomad_enable_ui }
}
EOF

  chown $NOMAD_USER:$NOMAD_GROUP $NOMAD_CONFIG_PATH
  chmod 640 $NOMAD_CONFIG_PATH
}

function template_nomad_systemd {
  log "[INFO]" "Templating out the Nomad service..."

  local kill_cmd=$(which kill)
  sudo bash -c "cat > $SYSTEMD_DIR/nomad.service" <<EOF
[Unit]
Description=HashiCorp Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target
ConditionFileNotEmpty=$NOMAD_CONFIG_PATH
StartLimitIntervalSec=60
StartLimitBurst=3

# When using Nomad with Consul it is not necessary to start Consul first. These
# lines start Consul before Nomad as an optimization to avoid Nomad logging
# that Consul is unavailable at startup.
#Wants=consul.service
#After=consul.service

[Service]
User=$NOMAD_USER
Group=$NOMAD_GROUP
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=$NOMAD_DIR_BIN/nomad agent -config $NOMAD_DIR_CONFIG
ExecReload=$${kill_cmd} --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=2
TimeoutStopSec=30
LimitNOFILE=65536
LimitNPROC=infinity
LimitMEMLOCK=infinity
EnvironmentFile=-$NOMAD_DIR_CONFIG/nomad.env
Type=notify
TasksMax=infinity
# Nomad Server agents should never be force killed,
# so here we disable OOM (out of memory) killing for this unit.
# However, you may wish to change this for Client agents, since
# the workloads that Nomad places may be more important
# than the Nomad agent itself.
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF
}

# start_enable_nomad starts and enables the nomad service
function start_enable_nomad {
  log "[INFO]" "Starting and enabling the nomad service..."

  sudo systemctl enable nomad
  sudo systemctl start nomad

  log "[INFO]" "Done starting and enabling the nomad service."
}

function exit_script {
  if [[ "$1" == 0 ]]; then
    log "INFO" "nomad_custom_data script finished successfully!"
  else
    log "ERROR" "nomad_custom_data script finished with error code $1."
  fi

  exit "$1"
}

function prepare_disk() {
  local device_name="$1"
  log "DEBUG" "prepare_disk - device_name; $${device_name}"

  local device_mountpoint="$2"
  log "DEBUG" "prepare_disk - device_mountpoint; $${device_mountpoint}"

  local device_label="$3"
  log "DEBUG" "prepare_disk - device_label; $${device_label}"

  sleep 20

  local device_id=$(readlink -f /dev/disk/by-id/$${device_name})
	  if [[ -z "$${device_id}" ]]; then
    log "ERROR" "No device found attached to device $${device_name}"
    exit_script 1
  fi

  log "DEBUG" "prepare_disk - device_id; $${device_id}"

  mkdir -p  $device_mountpoint

  # https://cloud.google.com/compute/docs/disks/optimizing-pd-performance#os-changes
  # exclude quotes on device_label or formatting will fail
  mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 -L $device_label $${device_id}

  echo "LABEL=$device_label $device_mountpoint ext4 defaults 0 2" >> /etc/fstab

  mount -a
}

function main {
  log "INFO" "Beginning Nomad user_data script."

  OS_DISTRO=$(detect_os_distro)
  log "INFO" "Detected Linux OS distro is '$OS_DISTRO'."

  OS_ARCH=$(detect_architecture)
	log "INFO" "Detected architecture is '$OS_ARCH'."

  scrape_vm_info
  install_prereqs "$OS_DISTRO"
  install_gcloud_sdk "$OS_DISTRO"

  log "INFO" "Preparing Nomad data disk"
  prepare_disk "google-persistent-disk-1" "${nomad_dir_home}" "nomad-data"

  log "INFO" "Preparing Nomad audit logs disk"
  prepare_disk "google-persistent-disk-2" $NOMAD_DIR_LOGS "nomad-audit"

  user_group_create
  directory_create

	checksum_verify $OS_ARCH
  log "INFO" "Installing Nomad version $NOMAD_VERSION for $OS_ARCH"

  log "INFO" "Installing Nomad version $NOMAD_VERSION for $OS_ARCH"
  install_nomad_binary  $OS_ARCH

	%{ if nomad_client ~}
  install_runtime
  install_cni_plugins
  configure_sysctl
  %{ endif ~}
  %{ if nomad_server ~}
  fetch_nomad_license
  fetch_nomad_gossip_key
  %{ endif ~}
  %{ if nomad_tls_enabled ~}
  fetch_tls_certificates
  %{ endif ~}
  generate_nomad_config
  template_nomad_systemd
  start_enable_nomad

  exit_script 0
}

main
