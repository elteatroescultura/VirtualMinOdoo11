#!/bin/sh
# Instala Todo lo necesario para un servidor ODOO 11 
# 10-02-2019
# 24-03-2019

 
# shellcheck disable=SC2059 disable=SC2181 disable=SC2154
# virtualmin-install.sh
# Copyright 2005-2019 Virtualmin, Inc.
# Simple script to grab the virtualmin-release and virtualmin-base packages.
# The packages do most of the hard work, so this script can be small-ish and
# lazy-ish.

# WARNING: Anything not listed in the currently supported systems list is not
# going to work, despite the fact that you might see code that detects your
# OS and acts on it.  If it isn't in the list, the code is not complete and
# will not work.  More importantly, the repos that this script uses do not
# exist, if the OS isn't listed.  Don't even bother trying it.
#
# A manual install might work for you though.
# See here: https://www.virtualmin.com/documentation/installation/manual/

# License and version
SERIAL=GPL
KEY=GPL
VER=6.0.17
vm_version=6

# Currently supported systems:
supported="    CentOS/RHEL Linux 6 and 7 on x86_64
    Debian 7, 8, and 9, on i386 and amd64
    Ubuntu 14.04 LTS and 16.04 LTS on i386 and amd64"

log=/root/virtualmin-install.log
skipyesno=0

# Print usage info, if --help, set mode, etc.
# Temporary colors
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
NORMAL="$(tput sgr0)"

# Set defaults
bundle='LAMP' # Other option is LEMP
mode='full' # Other option is minimal

usage () {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "${CYAN}" $(basename "$0")
  echo
  echo "  If called without arguments, installs Virtualmin."
  echo
  printf "  ${YELLOW}--uninstall|-u${NORMAL} - Removes all Virtualmin packages (do not use on a production system)\\n"
  printf "  ${YELLOW}--help|-h${NORMAL} - This message\\n"
  printf "  ${YELLOW}--force|-f${NORMAL} - Skip confirmation message\\n"
  printf "  ${YELLOW}--hostname|-n${NORMAL} - Set fully qualified hostname\\n"
  printf "  ${YELLOW}--verbose|-v${NORMAL} - Verbose\\n"
  printf "  ${YELLOW}--setup|-s${NORMAL} - Setup software repositories and exit (no installation or configuration)\\n"
  printf "  ${YELLOW}--minimal|-m${NORMAL} - Install a smaller subset of packages for low-memory/low-resource systems\\n"
  printf "  ${YELLOW}--bundle|-b <name>${NORMAL} - Choose bundle to install (LAMP or LEMP, defaults to LAMP)\\n"
  printf "  ${YELLOW}--disable <feature>${NORMAL} - Disable feature [SCL]\\n"
  echo
}

while [ "$1" != "" ]; do
  case $1 in
    --help|-h)
    usage
    exit 0
    ;;
    --uninstall|-u)
    shift
    mode="uninstall"
    ;;
    --force|-f|--yes|-y)
    shift
    skipyesno=1
    ;;
    --hostname|-n)
    shift
    forcehostname=$1
    shift
    ;;
    --verbose|-v)
    shift
    VERBOSE=1
    ;;
    --setup|-s)
    shift
    setup_only=1
    mode='setup'
    break
    ;;
    --minimal|-m)
    shift
    mode='minimal'
    ;;
    --disable)
    shift
    case "$1" in
      SCL)
      shift
      DISABLE_SCL=1
      ;;
      EPEL)
      shift
      DISABLE_EPEL=1
      ;;
      *)
      printf "Unknown feature ${YELLOW}$1${NORMAL}: exiting\\n"
      exit 1
      ;;
    esac
    ;;
    --bundle|-b)
    shift
    case "$1" in
      LAMP)
      shift
      bundle='LAMP'
      ;;
      LEMP)
      shift
      bundle='LEMP'
      ;;
      *)
      printf "Unknown bundle ${YELLOW}$1${NORMAL}: exiting\\n"
      exit 1
      ;;
    esac
    ;;
    *)
    printf "Unrecognized option: $1\\n\\n"
    usage
    exit 1
    ;;
  esac
done

# Make sure Perl is installed
printf "Checking for Perl..." >> $log
# loop until we've got a Perl or until we can't try any more
while true; do
  perl="$(which perl 2>/dev/null)"
  if [ -z "$perl" ]; then
    if [ -x /usr/bin/perl ]; then
      perl=/usr/bin/perl
      break
    elif [ -x /usr/local/bin/perl ]; then
      perl=/usr/local/bin/perl
      break
    elif [ -x /opt/csw/bin/perl ]; then
      perl=/opt/csw/bin/perl
      break
    elif [ "$perl_attempted" = 1 ] ; then
      printf "${RED}Perl could not be installed - Installation cannot continue.${NORMAL}\\n"
      exit 2
    fi
    # couldn't find Perl, so we need to try to install it
    echo 'Perl was not found on your system - Virtualmin requires it to run.'
    echo 'Attempting to install it now.'
    if [ -x /usr/bin/dnf ]; then
      dnf -y install perl >> $log
    elif [ -x /usr/bin/yum ]; then
      yum -y install perl >> $log
    elif [ -x /usr/bin/apt-get ]; then
      apt-get update >> $log
      apt-get -q -y install perl >> $log
    fi
    perl_attempted=1
    # Loop. Next loop should either break or exit.
  else
    break
  fi
done
printf "found Perl at $perl\\n" >> $log

# Check for wget or curl or fetch
printf "Checking for HTTP client..." >> $log
while true; do
  if [ -x "/usr/bin/wget" ]; then
    download="/usr/bin/wget -nv"
    break
  elif [ -x "/usr/bin/curl" ]; then
    download="/usr/bin/curl -f -s -L -O"
    break
  elif [ -x "/usr/bin/fetch" ]; then
    download="/usr/bin/fetch"
    break
  elif [ "$wget_attempted" = 1 ]; then
    printf "${RED}No HTTP client available. Could not install wget. Cannot continue.${NORMAL}\\n"
    exit 1
  fi

  # Made it here without finding a downloader, so try to install one
  wget_attempted=1
  if [ -x /usr/bin/dnf ]; then
    dnf -y install wget >> $log
  elif [ -x /usr/bin/yum ]; then
    yum -y install wget >> $log
  elif [ -x /usr/bin/apt-get ]; then
    apt-get update >> /dev/null
    apt-get -y -q install wget >> $log
  fi
done
if [ -z "$download" ]; then
  echo "Tried to install downloader, but failed. Do you have working network and DNS?"
fi
printf "found %s\\n" "$download" >> $log

arch="$(uname -m)"
if [ "$arch" = "i686" ]; then
  arch="i386"
fi
if [ "$SERIAL" = "GPL" ]; then
  LOGIN=""
  PRODUCT="GPL"
  repopath="gpl/"
else
  LOGIN="$SERIAL:$KEY@"
  PRODUCT="Professional"
  repopath=""
fi

# Virtualmin-provided packages
vmgroup="'Virtualmin Core'"
debvmpackages="virtualmin-core"
deps=
sclgroup="'Software Collections PHP 7 Environment'"

# This has to be installed before anything else, so it can be disabled during
# install, and turned back on after. This is ridiculous.
debpredeps="fail2ban"

if [ "$mode" = 'full' ]; then
  if [ "$bundle" = 'LAMP' ]; then
    rhgroup="'Virtualmin LAMP Stack'"
    debdeps="postfix virtualmin-lamp-stack"
    ubudeps="postfix virtualmin-lamp-stack"
  elif [ "$bundle" = 'LEMP' ]; then
    rhgroup="'Virtualmin LEMP Stack'"
    debdeps="postfix php*-fpm virtualmin-lemp-stack"
    ubudeps="postfix php*-fpm virtualmin-lemp-stack"
  fi
elif [ "$mode" = 'minimal' ]; then
  if [ "$bundle" = 'LAMP' ]; then
    rhgroup="'Virtualmin LAMP Stack Minimal'"
    debdeps="postfix virtualmin-lamp-stack-minimal"
    ubudeps="postfix virtualmin-lamp-stack-minimal"
  elif [ "$bundle" = 'LEMP' ]; then
    rhgroup="'Virtualmin LEMP Stack Minimal'"
    debdeps="postfix php*-fpm virtualmin-lemp-stack-minimal"
    ubudeps="postfix php*-fpm virtualmin-lemp-stack-minimal"
  fi
fi

# Find temp directory
if [ -z "$TMPDIR" ]; then
  TMPDIR=/tmp
fi

# Check whether $TMPDIR is mounted noexec (everything will fail, if so)
# XXX: This check is imperfect. If $TMPDIR is a full path, but the parent dir
# is mounted noexec, this won't catch it.
TMPNOEXEC="$(grep $TMPDIR /etc/mtab | grep noexec)"
if [ ! -z "$TMPNOEXEC" ]; then
  echo "${RED}Fatal:${NORMAL} $TMPDIR directory is mounted noexec. Installation cannot continue."
  exit 1
fi

if [ -z "$tempdir" ]; then
  tempdir="$TMPDIR/.virtualmin-$$"
  if [ -e "$tempdir" ]; then
    rm -rf "$tempdir"
  fi
  mkdir "$tempdir"
fi

# "files" subdir for libs
mkdir "$tempdir/files"
srcdir="$tempdir/files"
if ! cd "$srcdir"; then
  echo "Failed to cd to $srcdir"
  exit 1
fi

# Download the slib (source: http://github.com/virtualmin/slib)
# Lots of little utility functions.
$download https://software.virtualmin.com/lib/slib.sh
chmod +x slib.sh
# shellcheck disable=SC1091
. ./slib.sh

# Check the serial number and key
serial_ok "$SERIAL" "$KEY"
# Setup slog
# shellcheck disable=SC2034
LOG_PATH="$log"
# Setup run_ok
# shellcheck disable=SC2034
RUN_LOG="$log"
# Exit on any failure during shell stage
# shellcheck disable=SC2034
RUN_ERRORS_FATAL=1

# Console output level; ignore debug level messages.
if [ "$VERBOSE" = "1" ]; then
  # shellcheck disable=SC2034
  LOG_LEVEL_STDOUT="DEBUG"
else
  # shellcheck disable=SC2034
  LOG_LEVEL_STDOUT="INFO"
fi
# Log file output level; catch literally everything.
# shellcheck disable=SC2034
LOG_LEVEL_LOG="DEBUG"

# log_fatal calls log_error
log_fatal() {
  log_error "$1"
}

fatal () {
  echo
  log_fatal "Fatal Error Occurred: $1"
  printf "${RED}Cannot continue installation.${NORMAL}\\n"
  remove_virtualmin_release
  if [ -x "$tempdir" ]; then
    log_warning "Removing temporary directory and files."
    rm -rf "$tempdir"
  fi
  log_fatal "If you are unsure of what went wrong, you may wish to review the log"
  log_fatal "in $log"
  exit 1
}

remove_virtualmin_release () {
  # shellcheck disable=SC2154
  case "$os_type" in
    "fedora" | "centos" | "rhel" | "amazon"	)
    run_ok "rpm -e virtualmin-release" "Removing virtualmin-release"
    ;;
    "debian" | "ubuntu" )
    grep -v "virtualmin" /etc/apt/sources.list > "$tempdir"/sources.list
    mv "$tempdir"/sources.list /etc/apt/sources.list
    ;;
  esac
}

success () {
  log_success "$1 Succeeded."
}

# Function to find out if Virtualmin is already installed, so we can get
# rid of some of the warning message. Nobody reads it, and frequently
# folks run the install script on a production system; either to attempt
# to upgrade, or to "fix" something. That's never the right thing.
is_installed () {
  if [ -f /etc/virtualmin-license ]; then
    # looks like it's been installed before
    return 0
  fi
  # XXX Probably not installed? Maybe we should remove license on uninstall, too.
  return 1
}

# This function performs a rough uninstallation of Virtualmin
# It is neither complete, nor correct, but it almost certainly won't break
# anything.  It is primarily useful for cleaning up a botched install, so you
# can run the installer again.
uninstall () {
  # Very destructive, ask first.
  echo
  printf "  ${REDBG}WARNING${NORMAL}\\n"
  echo
  echo "  This operation is very destructive. It removes nearly all of the packages"
  echo "  installed by the Virtualmin installer. Never run this on a production system."
  echo
  printf " Continue? (y/n) "
  if ! yesno; then
    exit
  fi

  # This is a crummy way to detect package manager...but going through
  # half the installer just to get here is even crummier.
  if which rpm 1>/dev/null 2>&1; then package_type=rpm
  elif which dpkg 1>/dev/null 2>&1; then package_type=deb
  fi

case "$package_type" in
  rpm)
  yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin Core"
  yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LAMP Stack"
  yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LEMP Stack"
  yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LAMP Stack Minimal"
  yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LEMP Stack Minimal"
  yum remove -y virtualmin-base
  yum remove -y wbm-virtual-server wbm-virtualmin-htpasswd wbm-virtualmin-dav wbm-virtualmin-mailman wbm-virtualmin-awstats wbm-php-pear wbm-ruby-gems wbm-virtualmin-registrar wbm-virtualmin-init wbm-jailkit wbm-virtualmin-git wbm-virtualmin-slavedns wbm-virtual-server wbm-virtualmin-sqlite wbm-virtualmin-svn
  yum remove -y wbt-virtual-server-mobile
  yum remove -y virtualmin-config perl-Term-Spinner-Color
  yum remove -y webmin usermin awstats
  yum remove -y nginx
  yum remove -y fail2ban
  yum clean all; yum clean all
  os_type="centos"
  ;;
  deb)
  rm -rf /etc/fail2ban/jail.d/00-firewalld.conf
  rm -f /etc/fail2ban/jail.local
  apt-get remove --assume-yes --purge virtualmin-base virtualmin-core virtualmin-lamp-stack virtualmin-lemp-stack
  apt-get remove --assume-yes --purge virtualmin-lamp-stack-minimal virtualmin-lemp-stack-minimal
  apt-get remove --assume-yes --purge virtualmin-config libterm-spinner-color-perl
  apt-get remove --assume-yes --purge webmin-virtual-server webmin-virtualmin-htpasswd webmin-virtualmin-git webmin-virtualmin-slavedns webmin-virtualmin-dav webmin-virtualmin-mailman webmin-virtualmin-awstats webmin-php-pear webmin-ruby-gems webmin-virtualmin-registrar webmin-virtualmin-init webmin-jailkit webmin-virtual-server webmin-virtualmin-sqlite webmin-virtualmin-svn
  apt-get remove --assume-yes --purge webmin-virtual-server-mobile
  apt-get remove --assume-yes --purge fail2ban
  apt-get remove --assume-yes --purge apache2*
  apt-get remove --assume-yes --purge nginx*
  apt-get remove --assume-yes --purge webmin usermin
  apt-get autoremove --assume-yes
  os_type="debian"
  apt-get clean
  ;;
  *)
  echo "I don't know how to uninstall on this operating system."
  ;;
esac
echo 'Removing nameserver 127.0.0.1 from /etc/resolv.conf'
sed -i '/nameserver 127.0.0.1/g' /etc/resolv.conf
echoo 'Removing virtualmin repo configuration'
remove_virtualmin_release
echo "Removing /etc/virtualmin-license, if it exists."
rm /etc/virtualmin-license
echo "Done.  There's probably quite a bit of related packages and such left behind"
echo "but all of the Virtualmin-specific packages have been removed."
exit 0
}
if [ "$mode" = "uninstall" ]; then
  uninstall
fi

# Calculate disk space requirements (this is a guess, for now)
if [ "$mode" = 'minimal' ]; then
  disk_space_required=500
else
  disk_space_required=650
fi

# Message to display in interactive mode
install_msg() {
cat <<EOF

  Welcome to the Virtualmin ${GREEN}$PRODUCT${NORMAL} installer, version ${GREEN}$VER${NORMAL}

  This script must be run on a freshly installed supported OS. It does not
  perform updates or upgrades (use your system package manager) or license
  changes (use the "virtualmin change-license" command).

  The systems currently supported by install.sh are:

EOF
echo "${CYAN}$supported${NORMAL}"
cat <<EOF

  If your OS/version/arch is not listed, installation ${RED}will fail${NORMAL}. More
  details about the systems supported by the script can be found here:

    ${UNDERLINE}https://www.virtualmin.com/os-support${NORMAL}

  The selected package bundle is ${CYAN}${bundle}${NORMAL} and the size of install is
  ${CYAN}${mode}${NORMAL}. It will require up to ${CYAN}${disk_space_required} MB${NORMAL} of disk space.

  Exit and re-run this script with ${CYAN}--help${NORMAL} flag to see available options.

EOF

  printf " Continue? (y/n) "
  if ! yesno; then
    exit
  fi
}
if [ "$skipyesno" -ne 1 ] && [ -z "$setup_only" ]; then
  install_msg
fi

already_installed_msg() {
  # Double check if installed, just in case above error ignored.
  if is_installed; then
cat <<EOF

  ${REDBG}WARNING${NORMAL}

  Virtualmin may already be installed. This can happen if an installation failed,
  and can be ignored in that case.

  But, if Virtualmin has already successfully installed you should not run this
  script again! It will cause breakage to your existing configuration.

  Updates and upgrades can be performed from within Virtualmin. To change
  license details, use the 'virtualmin change-license' command.

  Changing the license never requires re-installation.

EOF
    printf " Really Continue? (y/n) "
    if ! yesno; then
      exit
    fi
  fi
}
if [ "$skipyesno" -ne 1 ] && [ -z "$setup_only" ]; then
  already_installed_msg
fi

# Check memory
if [ "$mode" = "full" ]; then
  minimum_memory=1048576
else
  # minimal mode probably needs less memory to succeed
  minimum_memory=786432
fi
if ! memory_ok "$minimum_memory"; then
  log_fatal "Too little memory, and unable to create a swap file. Consider adding swap"
  log_fatal "or more RAM to your system."
  exit 1
fi

# Check for localhost in /etc/hosts
if [ -z "$setup_only" ]; then
  grep localhost /etc/hosts >/dev/null
  if [ "$?" != 0 ]; then
    log_warning "There is no localhost entry in /etc/hosts. This is required, so one will be added."
    run_ok "echo 127.0.0.1 localhost >> /etc/hosts" "Editing /etc/hosts"
    if [ "$?" -ne 0 ]; then
      log_error "Failed to configure a localhost entry in /etc/hosts."
      log_error "This may cause problems, but we'll try to continue."
    fi
  fi
fi

# download()
# Use $download to download the provided filename or exit with an error.
download() {
  # XXX Check this to make sure run_ok is doing the right thing.
  # Especially make sure failure gets logged right.
  # awk magic prints the filename, rather than whole URL
  download_file=$(echo "$1" |awk -F/ '{print $NF}')
  run_ok "$download $1" "Downloading $download_file"
  if [ $? -ne 0 ]; then
    fatal "Failed to download $1. Cannot continue. Check your network connection and DNS settings."
  else
    return 0
  fi
}

# Only root can run this
id | grep -i "uid=0(" >/dev/null
if [ "$?" != "0" ]; then
  uname -a | grep -i CYGWIN >/dev/null
  if [ "$?" != "0" ]; then
    fatal "${RED}Fatal:${NORMAL} The Virtualmin install script must be run as root"
  fi
fi

log_info "Started installation log in $log"
echo
if [ ! -z $setup_only ]; then
  log_debug "Phase 1 of 1: Setup"
  printf "${YELLOW}▣${NORMAL} Phase ${YELLOW}1${NORMAL} of ${GREEN}1${NORMAL}: Setup\\n"
else
  log_debug "Phase 1 of 3: Setup"
  printf "${YELLOW}▣${CYAN}□□${NORMAL} Phase ${YELLOW}1${NORMAL} of ${GREEN}3${NORMAL}: Setup\\n"
fi

# Print out some details that we gather before logging existed
log_debug "Install mode: $mode"
log_debug "Product: Virtualmin $PRODUCT"
log_debug "install.sh version: $VER"

# Check for a fully qualified hostname
log_debug "Checking for fully qualified hostname..."
name="$(hostname -f)"
if [ ! -z "$forcehostname" ]; then set_hostname "$forcehostname"
elif ! is_fully_qualified "$name"; then set_hostname
fi

# Insert the serial number and password into /etc/virtualmin-license
log_debug "Installing serial number and license key into /etc/virtualmin-license"
echo "SerialNumber=$SERIAL" > /etc/virtualmin-license
echo "LicenseKey=$KEY"	>> /etc/virtualmin-license
chmod 700 /etc/virtualmin-license
cd ..

# Populate some distro version globals
get_distro
log_debug "Operating system name:    $os_real"
log_debug "Operating system version: $os_version"
log_debug "Operating system type:    $os_type"
log_debug "Operating system major:   $os_major_version"

install_virtualmin_release () {
  # Grab virtualmin-release from the server
  log_debug "Configuring package manager for ${os_real} ${os_version}..."
  case "$os_type" in
    rhel|centos|fedora|amazon)
    case "$os_type" in
      rhel|centos)
      if [ "$os_major_version" -lt 6 ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
      fedora)
      if [ "$os_version" -ne 25 ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
      ubuntu)
      if [ "$os_version" != "14.04" ] && [ "$os_version" != "16.04" ] && [ "$os_version" != "18.04" ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
      debian)
      if [ "$os_major_version" -lt 7 ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
      *)
      printf "${RED}This OS/version is not recognized. Can't continue.${NORMAL}\\n"
      exit 1
      ;;
    esac
    if [ -x /usr/sbin/setenforce ]; then
      log_debug "Disabling SELinux during installation..."
      if /usr/sbin/setenforce 0; then log_debug " setenforce 0 succeeded"
    else log_debug "  setenforce 0 failed: $?"
    fi
  fi
  package_type="rpm"
  if which dnf 1>/dev/null 2>&1; then
    install="dnf -y install"
    install_cmd="dnf"
    install_group="dnf -y --quiet group install --setopt=group_package_types=mandatory,default"
  else
    install="/usr/bin/yum -y install"
    install_cmd="/usr/bin/yum"
    if [ "$os_major_version" -ge 7 ]; then
      run_ok "yum --quiet groups mark convert" "Updating yum Groups"
    fi
    install_group="yum -y --quiet groupinstall --setopt=group_package_types=mandatory,default"
  fi
  download "https://${LOGIN}software.virtualmin.com/vm/${vm_version}/${repopath}${os_type}/${os_major_version}/${arch}/virtualmin-release-latest.noarch.rpm"
  run_ok "rpm -U --replacepkgs --quiet virtualmin-release-latest.noarch.rpm" "Installing virtualmin-release package"
  ;;
  debian | ubuntu)
  package_type="deb"
  if [ "$os_type" = "ubuntu" ]; then
    deps="$ubudeps"
    case "$os_version" in
      14.04*)
      run_ok "add-apt-repository -y ppa:ondrej/php" "Enabling PHP 7 PPA"
      repos="virtualmin-trusty virtualmin-universal"
      ;;
      16.04*)
      repos="virtualmin-xenial virtualmin-universal"
      ;;
      18.04*)
      repos="virtualmin-bionic virtualmin-universal"
      ;;
    esac
  else
    deps="$debdeps"
    case "$os_version" in
      7*)
      repos="virtualmin-wheezy virtualmin-universal"
      ;;
      8*)
      run_ok "apt-get install --assume-yes apt-transport-https lsb-release ca-certificates" "Installing extra dependencies for Debian 8"
      download 'https://packages.sury.org/php/apt.gpg'
      run_ok "cp apt.gpg /etc/apt/trusted.gpg.d/php.gpg" "Adding GPG key for PHP7 packages"
      echo "deb http://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
      repos="virtualmin-jessie virtualmin-universal"
      ;;
      9*)
      repos="virtualmin-stretch virtualmin-universal"
      ;;
    esac
  fi
  log_debug "apt-get repos: ${repos}"
  if [ -z "$repos" ]; then # Probably unstable with no version number
    log_fatal "No repos available for this OS. Are you running unstable/testing?"
    exit 1
  fi
  for repo in $repos; do
    printf "deb http://${LOGIN}software.virtualmin.com/vm/${vm_version}/${repopath}apt ${repo} main\\n" >> /etc/apt/sources.list
  done
  # Install our keys
  log_debug "Installing Webmin and Virtualmin package signing keys..."
  download "https://software.virtualmin.com/lib/RPM-GPG-KEY-virtualmin-6"
  download "https://software.virtualmin.com/lib/RPM-GPG-KEY-webmin"
  run_ok "apt-key add RPM-GPG-KEY-virtualmin-6" "Installing Virtualmin 6 key"
  run_ok "apt-key add RPM-GPG-KEY-webmin" "Installing Webmin key"
  run_ok "apt-get update" "Updating apt metadata"
  run_ok "apt-get update" "Downloading repository metadata"
  # Make sure universe repos are available
  # XXX Test to make sure this run_ok syntax works as expected (with single quotes inside double)
  if [ $os_type = "ubuntu" ]; then
    if [ -x "/bin/add-apt-repository" ] || [ -x "/usr/bin/add-apt-repository" ]; then 
      run_ok "add-apt-repository universe" \
        "Enabling universe repositories, if not already available"
    else
      run_ok "sed -ie '/backports/b; s/#*[ ]*deb \\(.*\\) universe$/deb \\1 universe/' /etc/apt/sources.list" \
        "Enabling universe repositories, if not already available"
    fi
  fi
  # XXX Is this still enabled by default on Debian/Ubuntu systems?
  run_ok "sed -ie 's/^deb cdrom:/#deb cdrom:/' /etc/apt/sources.list" "Disabling cdrom: repositories"
  install="DEBIAN_FRONTEND='noninteractive' /usr/bin/apt-get --quiet --assume-yes --install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' -o Dpkg::Pre-Install-Pkgs::='/usr/sbin/dpkg-preconfigure --apt' install"
  #export DEBIAN_FRONTEND=noninteractive
  install_updates="$install $deps"
  run_ok "apt-get clean" "Cleaning out old metadata"
  sed -i "s/\\(deb[[:space:]]file.*\\)/#\\1/" /etc/apt/sources.list
  ;;
  *)
  log_error " Your OS is not currently supported by this installer."
  log_error " You can probably run Virtualmin Professional on your system, anyway,"
  log_error " but you'll have to install it using the manual installation process."
  exit 1
  ;;
esac

return 0
}
if [ ! -z "$setup_only" ]; then
  if install_virtualmin_release; then
    log_success "Repository configuration successful. You can now install Virtualmin"
    log_success "components using your OS package manager."
  else
    log_error "Errors occurred during setup of Virtualmin software repositories. You may find more"
    log_error "information in ${RUN_LOG}."
  fi
  exit $?
fi

# Install Functions
install_with_apt () {
  # Install Webmin first, because it needs to be already done for the deps
  run_ok "$install webmin" "Installing Webmin"
  run_ok "$install usermin" "Installing Usermin"
  for d in $debpredeps; do
    run_ok "$install $d" "Installing $d"
  done
  if [ $bundle = 'LEMP' ]; then
    # This is bloody awful. I can't believe how fragile dpkg is here.
    for s in fail2ban ipchains apache2; do
      systemctl stop "$s">>${RUN_LOG} 2>&1
      systemctl disable "$s">>${RUN_LOG} 2>&1
    done
    run_ok 'apt-get remove --assume-yes --purge apache2* php*' 'Removing apache2 (if installed) before LEMP installation.'
    run_ok 'apt-get autoremove --assume-yes' 'Removing unneeded packages that could confict with LEMP stack.'
    run_ok "$install nginx-common" "Installing nginx-common"
    sed -i 's/listen \[::\]:80 default_server;/#listen \[::\]:80 default_server;/' /etc/nginx/sites-available/default
  else
    # This is bloody awful. I can't believe how fragile dpkg is here.
    for s in fail2ban nginx; do
      systemctl stop "$s">>${RUN_LOG} 2>&1
      systemctl disable "$s">>${RUN_LOG} 2>&1
    done
    run_ok 'apt-get remove --assume-yes --purge nginx* php*' 'Removing nginx (if installed) before LAMP installation.'
    run_ok 'apt-get autoremove --assume-yes' 'Removing unneeded packages that could confict with LAMP stack.'
  fi
  for d in ${deps}; do
    run_ok "$install ${d}" "Installing $d"
  done
  run_ok "$install ${debvmpackages}" "Installing Virtualmin and plugins"
  if [ $? -ne 0 ]; then
    log_warning "apt-get seems to have failed. Are you sure your OS and version is supported?"
    log_warning "https://www.virtualmin.com/os-support"
    fatal "Installation failed: $?"
  fi

  # Make sure the time is set properly
  /usr/sbin/ntpdate-debian 2>/dev/null 2>&1

  return 0
}

install_with_yum () {
  # install extras from EPEL and SCL
  if [ "$os_type" = "centos" ] || [ "$os_type" = "rhel" ]; then
    install_epel_release
    install_scl_php
  fi

  # XXX This is so stupid. Why does yum insist on extra commands?
  if [ "$os_major_version" -ge 7 ]; then
    run_ok "yum --quiet groups mark install $rhgroup" "Marking $rhgroup for install"
    run_ok "yum --quiet groups mark install $vmgroup" "Marking $vmgroup for install"
  fi
  run_ok "$install_group $rhgroup" "Installing dependencies and system packages"
  run_ok "$install_group $vmgroup" "Installing Virtualmin and all related packages"
  if [ $? -ne 0 ]; then
    fatal "Installation failed: $?"
  fi

  run_ok "$install_cmd clean all" "Cleaning up software repo metadata"

  return 0
}

install_virtualmin () {
  case "$package_type" in
    rpm)
    install_with_yum
    ;;
    deb)
    install_with_apt
    ;;
    *)
    install_with_tar
    ;;
  esac
  if [ $? -eq 0 ]; then
    return 0
  else
    return $?
  fi
}

install_epel_release () {
  if [ -z "$DISABLE_EPEL" ]; then
    download "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${os_major_version}.noarch.rpm"
    run_ok "rpm -U --replacepkgs --quiet epel-release-latest-${os_major_version}.noarch.rpm" "Installing EPEL release package"
    rpm --quiet --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-*" 1>/dev/null 2>&1
  fi
}

install_scl_php () {
  if [ -z "$DISABLE_SCL" ]; then
    run_ok "$install yum-utils" "Installing yum-utils"
    run_ok "yum-config-manager --enable extras >/dev/null" "Enabling extras repository"
    run_ok "$install scl-utils" "Installing scl-utils"
    if [ "${os_type}" = "centos" ]; then
      run_ok "$install centos-release-scl" "Install Software Collections release package"
    elif [ "${os_type}" = "rhel" ]; then
      # XXX Fix this for dnf (dnf config-manager, instead of yum-config-manager)
      run_ok "yum-config-manager --enable rhel-server-rhscl-${os_major_version}-rpms" "Enabling Server Software Collection"
    fi
    run_ok "$install_group $sclgroup" "Installing PHP7"
  fi
}

# virtualmin-release only exists for one platform...but it's as good a function
# name as any, I guess.  Should just be "setup_repositories" or something.
errors=$((0))
install_virtualmin_release
echo
log_debug "Phase 2 of 3: Installation"
printf "${GREEN}▣${YELLOW}▣${CYAN}□${NORMAL} Phase ${YELLOW}2${NORMAL} of ${GREEN}3${NORMAL}: Installation\\n"
install_virtualmin
if [ "$?" != "0" ]; then
  errorlist="${errorlist}  ${YELLOW}◉${NORMAL} Package installation returned an error.\\n"
  errors=$((errors + 1))
fi

# We want to make sure we're running our version of packages if we have
# our own version.  There's no good way to do this, but we'll
run_ok "$install_updates" "Installing updates to Virtualmin-related packages"
if [ "$?" != "0" ]; then
  errorlist="${errorlist}  ${YELLOW}◉${NORMAL} Installing updates returned an error.\\n"
  errors=$((errors + 1))
fi

# Reap any clingy processes (like spinner forks)
# get the parent pids (as those are the problem)
allpids="$(ps -o pid= --ppid $$) $allpids"
for pid in $allpids; do
  kill "$pid" 1>/dev/null 2>&1
done

# Final step is configuration. Wait here for a moment, hopefully letting any
# apt processes disappear before we start, as they're huge and memory is a
# problem. XXX This is hacky. I'm not sure what's really causing random fails.
sleep 1
echo
log_debug "Phase 3 of 3: Configuration"
printf "${GREEN}▣▣${YELLOW}▣${NORMAL} Phase ${YELLOW}3${NORMAL} of ${GREEN}3${NORMAL}: Configuration\\n"
if [ "$mode" = "minimal" ]; then
  bundle="Mini${bundle}"
fi
virtualmin-config-system --bundle "$bundle"
if [ "$?" != "0" ]; then
  errorlist="${errorlist}  ${YELLOW}◉${NORMAL} Postinstall configuration returned an error.\\n"
  errors=$((errors + 1))
fi
config_system_pid=$!

# Functions that are used in the OS specific modifications section
disable_selinux () {
  seconfigfiles="/etc/selinux/config /etc/sysconfig/selinux"
  for i in $seconfigfiles; do
    if [ -e "$i" ]; then
      perl -pi -e 's/^SELINUX=.*/SELINUX=disabled/' "$i"
    fi
  done
}

# Changes that are specific to OS
case "$os_type" in
  "fedora" | "centos" | "rhel" | "amazon" )
  disable_selinux
  ;;
esac


# kill the virtualmin config-system command, if it's still running
kill "$config_system_pid" 1>/dev/null 2>&1
# Make sure the cursor is back (if spinners misbehaved)
tput cnorm


printf "${GREEN}▣▣▣${NORMAL} Cleaning up\\n"
# Cleanup the tmp files
if [ "$tempdir" != "" ] && [ "$tempdir" != "/" ]; then
  log_debug "Cleaning up temporary files in $tempdir."
  find "$tempdir" -delete
else
  log_error "Could not safely clean up temporary files because TMPDIR set to $tempdir."
fi

if [ ! -z "$QUOTA_FAILED" ]; then
  log_warning "Quotas were not configurable. A reboot may be required. Or, if this is"
  log_warning "a VM, configuration may be required at the host level."
fi
echo
if [ $errors -eq "0" ]; then
  hostname=$(hostname -f)
  detect_ip
  log_success "Installation Complete!"
  log_success "If there were no errors above, Virtualmin should be ready"
  log_success "to configure at https://${hostname}:10000 (or https://${address}:10000)."
  log_success "You'll receive a security warning in your browser on your first visit."
else
  log_warning "The following errors occurred during installation:"
  echo
  printf "${errorlist}"
  log_warning "The last few lines of the log file were:"
  tail -15 $RUN_LOG
fi


#Step 3 — Configuring Webmin's Root Password
sudo /usr/share/webmin/changepass.pl /etc/webmin root MOISES1_1980
sudo systemctl restart webmin


################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################


#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Choose the Odoo version which you want to install. For example: 13.0, 12.0, 11.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 13.0
OE_VERSION="11.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# Set this to True if you want to install Nginx!
INSTALL_NGINX="True"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
# Set the website name
WEBSITE_NAME="_"
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Provide Email to register ssl certificate
ADMIN_EMAIL="moises.arancibia.sanchez@gmail.com"
##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltopdf installed, for a danger note refer to
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/13.0/setup/install.html#debian-ubuntu

WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_i386.deb
#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
# universe package is for Ubuntu 18.x
sudo add-apt-repository universe
# libpng12-0 dependency for wkhtmltopdf
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql postgresql-server-dev-all -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 libjpeg-dev gdebi -y

echo -e "\n---- Install python packages/requirements ----"
sudo -H pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 13 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo -H pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"


sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
if [ $OE_VERSION > "11.0" ];then
    sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# Specify the user name (Default: odoo).
USER=$OE_USER
# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* Security Init File"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "* Start ODOO on Startup"
sudo update-rc.d $OE_CONFIG defaults

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n---- Installing and setting up Nginx ----"
  sudo apt install nginx -y
  cat <<EOF > ~/odoo
  server {
  listen 80;

  # set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Add Headers for odoo proxy mode
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  #   odoo    log files
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log       /var/log/nginx/$OE_USER-error.log;

  #   increase    proxy   buffer  size
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   force   timeouts    if  the backend dies
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  types {
  text/less less;
  text/scss scss;
  }

  #   enable  data    compression
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
  proxy_pass    http://127.0.0.1:$OE_PORT;
  # by default, do not forward anything
  proxy_redirect off;
  }

  location /longpolling {
  proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }
  location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
  expires 2d;
  proxy_pass http://127.0.0.1:$OE_PORT;
  add_header Cache-Control "public, no-transform";
  }
  # cache some static data in memory for 60mins.
  location ~ /[a-zA-Z0-9_-]*/static/ {
  proxy_cache_valid 200 302 60m;
  proxy_cache_valid 404      1m;
  proxy_buffering    on;
  expires 864000;
  proxy_pass    http://127.0.0.1:$OE_PORT;
  }
  }
EOF

  sudo mv ~/odoo /etc/nginx/sites-available/
  sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
  sudo rm /etc/nginx/sites-enabled/default
  sudo service nginx reload
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/odoo"
else
  echo "Nginx isn't installed due to choice of the user!"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ]  && [ $WEBSITE_NAME != "_" ];then
  sudo add-apt-repository ppa:certbot/certbot -y && sudo apt-get update -y
  sudo apt-get install python-certbot-nginx -y
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo service nginx reload
  echo "SSL/HTTPS is enabled!"
else
  echo "SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration!"
fi

echo -e "* Starting Odoo Service"
sudo su root -c "/etc/init.d/$OE_CONFIG start"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "Configuration file location: /etc/${OE_CONFIG}.conf"
echo "Logfile location: /var/log/$OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Password superadmin (database): $OE_SUPERADMIN"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx configuration file: /etc/nginx/sites-available/odoo"
fi
echo "-----------------------------------------------------------"
