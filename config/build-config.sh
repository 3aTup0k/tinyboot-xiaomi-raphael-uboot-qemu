# System type configuration
SYSTEM_TYPES="
  tinyboot-iphoneos
"

# Mapping from system type to base settings
system_config() {
  case "$1" in
    "tinyboot-iphoneos")
      echo "DEBIAN_VERSION=${DEBIAN_VERSION:-trixie}"
      echo "IMAGE_SIZE=1G"
      echo "IS_DESKTOP=false"
      echo "DESKTOP_ENV="
      ;;
  esac
}

# Mirror configuration
sources_config() {
  if [[ "$1" == *"tinyboot-iphoneos"* ]]; then
    local version="${DEBIAN_VERSION:-trixie}"
    echo "DEBIAN_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/debian/"
    echo "DEBIAN_SECURITY_MIRROR=http://security.debian.org/debian-security"
  fi
}

# Package configuration
get_packages() {
  local system_type="$1"
  local desktop_env="$2"

  # Original debian-server base packages
  base_packages="bash-completion sudo apt-utils ssh openssh-server nano network-manager systemd-boot initramfs-tools chrony curl wget locales tzdata dnsmasq iptables iproute2 zram-tools"

  if [[ "$system_type" == "tinyboot-iphoneos" ]]; then
    echo "$base_packages"
  else
    echo "bash coreutils"
  fi
}


# Mirror configuration
sources_config() {
  if [[ "$1" == *"tinyfs-iphoneos"* ]]; then
    local version="${DEBIAN_VERSION:-trixie}"
    echo "DEBIAN_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/debian/"
    echo "DEBIAN_SECURITY_MIRROR=http://security.debian.org/debian-security"
  fi
}

# Package configuration
get_packages() {
  local system_type="$1"
  local desktop_env="$2"

  # Removed systemd-boot and initramfs-tools to avoid conflicts with OpenRC
  base_packages="bash-completion sudo apt-utils ssh openssh-server nano network-manager chrony curl wget locales tzdata dnsmasq iptables iproute2 zram-tools openrc"

  if [[ "$system_type" == "tinyfs-iphoneos" ]]; then
    echo "$base_packages"
  else
    echo "bash coreutils"
  fi
}
