#!/bin/bash
set -o pipefail
set -e

# Set umask so that groups have read/write access
umask 0002

# Declare a list of signals to trap so cleanup functionality can be performed if the script is interrupted
# NOTE: Must be in text format to exit with proper code (e.g. SIGINT, not 2)
readonly TRAP_SIGNALS=(SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGSEGV SIGSTKFLT)

# Capture the command used to start this process for later reporting
arg_set="$0 $*"
config_repo_root=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")
releases=${config_repo_root}/releases
spacklemore=${config_repo_root}/spacklemore

# Default settings for optional parameters
reindex_def=false # Don't reindex
concretize_def=false # Don't concretize
skip_install_def=false # Do an install
module_def=false # Don't generate modulefiles
stage_def=false # Don't stop after staging everything (before doing concretization, install, etc)
no_stage_def=false # Don't skip over the stage step
force_bootstrap_def=false # Don't force the use of the bootstrap script if it has already been run
prod_buildcache_def=false # Don't upload binarycache to production. Defaults to development.
buildcache_upload_def=true # Upload buildcache to pe-serve.
cert_store_def="" # Path to certificates.
ignorecache_def=false # Allow buildcache to be used.
install_path_len_def='74' # This is the length of the CI path that we have configured
spack_url_def='https://github.com/spack/spack' # URL for the official spack repo
verbose_def=false # Don't do verbose output
user_spack_ok_def=false # Don't allow user spack config files
num_nodes_def=0 # Number of nodes to use when building in parallel
time_limit_def='01:00:00' # Time limit of jobs when building in parallel
shared_group_def="" # The group that will own the files built
delete_tree_def=false # If true the --delete-tree flag will be used when refreshing modules
delete_tree="" # This will be set to --delete-tree and used as a flag in the spack module refresh command

usage () {
    echo ""
    echo "Usage: $0 [-f facility] [-e environment] [-r release] [-i install_dir] [args]"
    echo ""
    echo "  'facility' must be specified through the command line or environment"
    echo "  variable. 'environment', 'release' and 'install_dir' must be"
    echo "  specified through the command line, environment, or process.cfg file."
    echo ""
    echo "  -C|--cache-only"
    echo "  When building out on a machine, we'd like to force it to only utilize"
    echo "  binary caches, not build anything from source"
    echo ""
    echo "  -f|--facility <facility>"
    echo "      Name of the facility directory for this deployment.  This"
    echo "      will contain spack and other configs (including the process.cfg"
    echo "      config for this script). These are looked for in this repo's"
    echo "      'facilities' directory by default, but may be an absolute path."
    echo "      Environment Variable: TCE_FACILITY"
    echo "      NOTE: the environment variable for this option is the only one"
    echo "      that can NOT be put in to a process.cfg file as this option is"
    echo "      needed to find the process.cfg file. All other environment variables"
    echo "      mentioned in this help can be placed in a facility's process.cfg file."
    echo ""
    echo "  -r|--release <release>"
    echo "      Name of the release to build. Under each release are release specific "
    echo "      files and a set of supported environments. Releases are located in "
    echo "      the 'releases' directory."
    echo "      Environment Variable: TCE_RELEASE"
    echo ""
    echo "  -e|--environment <environment>"
    echo "      Each release may have multiple release 'environments' available, which "
    echo "      are versions of a TCE release targetting different base OS's and hardware."
    echo "      Environment Variable: TCE_ENVIRONMENT"
    echo ""
    echo "  -l|--licenses <license_path>"
    echo "      Path to the license directory. Spack will make a symlink to here. By default "
    echo "      licenses are copied from the 'licenses' directory in the selected facility."
    echo "      Environment Variable: TCE_LICENSES"
    echo ""
    echo "  -i|--install-prefix <path-without-version>"
    echo "      Specify the prefix under which all work should be done,"
    echo "      including installation.  The version will automatically be"
    echo "      appended to this path."
    echo "      Environment Variable: TCE_INSTALL_DIR"
    echo ""
    echo "  -b|--buildcache <build_cache_path>"
    echo "      When given, create binary buildcache of the environment in"
    echo "      the directory specified by <build_cache_path>. "
    echo "      Environment Variable: TCE_BUILDCACHE"
    echo ""
    echo "  --cert-store <cert_store path>"
    echo "      Path to cert store for the upload_tree script"
    echo "      Used to perform client identification when uploading the build cache "
    echo "      and for deriving paths for the signing keys."
    echo "      Environment Variable: TCE_CERT_STORE"
    echo ""
    echo "  --secret <path>"
    echo "      This is the signing key for binary cache packages. "
    echo "      These should be generated (and exported) using 'spack gpg create' prior to "
    echo "      executing this script."
    echo "      Default: <cert_store>/secring.gpg is used. "
    echo "      Environment Variable: TCE_SECRET"
    echo ""
    echo "  --public-key <path>"
    echo "      The public key for verifying packages. "
    echo "      Defaults to <cert_store>/pubring.gpg"
    echo "      environment variable: TCE_PUBLIC_KEY"
    echo ""
    echo "  --prod-buildcache"
    echo "      Uploades the binary cache to the production buildcache"
    echo "      Default: $prod_buildcache_def"
    echo ""
    echo "  --no-buildcache-upload"
    echo "      Disables buildcache upload to pe-serve"
    echo "      Default: $buildcache_upload_def"
    echo ""
    echo "  --skip-buildcache-on-failure"
    echo "  On install or other failure, skip buildcache generation."
    echo ""
    echo "  -g|--shared_group <group-name>"
    echo "      When given, set the group owner of the software built to the specified group"
    echo "      Environment Variable: TCE_SHARED_GROUP"
    echo ""
    echo "  --ignore-cache"
    echo "      Don't use the build cache if there is one when installing spack"
    echo "      packages."
    echo "      Default: $ignorecache_def"
    echo ""
    echo "  -d|--debug"
    echo "      Activate 'set -x' in the script."
    echo ""
    echo "  -c|--concretize"
    echo "      Specify that the stacks should be reconcretized before"
    echo "      installing."
    echo "      Default: $concretize_def"
    echo ""
    echo "  -s|--skip-install"
    echo "      Skip the installation step.  Useful for just updating modules. "
    echo "      Default: $skip_install_def"
    echo ""
    echo "  -B|--force-bootstrap"
    echo "      Force the bootstrap script to run, even if it's been completed before."
    echo "      Note that a check is done to determine if the bootstrap script has been"
    echo "      run already, so it will be run at least once for a TCE area."
    echo "      Default: $force_bootstrap_def"
    echo ""
    echo "  -m|--module"
    echo "      Specify that the modules should be regenerated after installing."
    echo "      Default: $module_def"
    echo ""
    echo "  -D|--delete-module-tree"
    echo "      The modulefile tree will be deleted before the refresh."
    echo "      Default: $delete_tree_def"
    echo ""
    echo "  --stage"
    echo "      Stop script after setting everything up but before"
    echo "      concretization, installation, and/or module generation."
    echo "      Default: $stage_def"
    echo ""
    echo "  --no-stage"
    echo "      Skip over stage step, this assumes that the Spacklemore and Spack"
    echo "      repos are already in place by another means (i.e., --stage, then sync) before"
    echo "      concretization, installation, and/or module generation."
    echo "      Default: $no_stage_def"
    echo ""
    echo "  --root <install_root>"
    echo "      Rewrite the install root in the spack config for the environment."
    echo "      This is used primarily for ci builds"
    echo "      Default: Defaults to \$spack/.. when creating a buildcache, otherwise "
    echo "               is left unset."
    echo ""
    echo "  -R|--reindex"
    echo "      Calls 'spack reindex' prior to concretization"
    echo "      This Spack subcommand rebuilds Spack’s package database."
    echo "      Default: $reindex_def"
    echo ""
    echo "  -p|--parallel <num_nodes>"
    echo "      Specify that the install should also be run on the number of"
    echo "      nodes given. A value of '0' signifies that parallel installs"
    echo "      are not to be done."
    echo "      Environment Variable: TCE_NUM_NODES"
    echo "      Default: $num_nodes_def"
    echo ""
    echo "  -t|--time-limit <time>"
    echo "      Time limit to give for the allocations obtained when doing"
    echo "      parallel installs.  Jobs will be relaunched after they complete"
    echo "      until all packages are installed."
    echo "      Environment Variable: TCE_TIME_LIMIT"
    echo "      Default: $time_limit_def"
    echo ""
    echo "  -U|--user-spack-ok"
    echo "      Tell this script that the existance of a ~/.spack directory is ok."
    echo "      The contents of that directory can cause enumerable problems."
    echo "      Default: $user_spack_ok_def"
    echo ""
    echo "  -v|--verbose"
    echo "      Set the verbosity of spack to high. On the upside, you'll have much "
    echo "      more info to debug problems. On the downside, CI based processes "
    echo "      will quickly hit the output capture limit. (Note that logs from "
    echo "      each step are saved as artifacts)."
    echo "      Default: $verbose_def"
    echo ""
    echo "  --spack-url <url>"
    echo "      Specify a URL from which to clone Spack."
    echo "      Environment Variable: TCE_SPACK_URL"
    echo "      Default: $spack_url_def"
    echo ""
    echo "  --spack-checkout [tag:]<REF>"
    echo "      By default, the spack repository is used as-is after cloning. Use"
    echo "      this option to checkout a particular git reference REF inside the spack"
    echo "      repository. REF can be a branch, commit, or tag reference. If the"
    echo "      reference is a tag, it is necessary to prepend the reference with 'tag:'."
    echo "      Examples:"
    echo "      To checkout the develop branch:"
    echo "        --spack-checkout develop"
    echo "      To checkout commit ffffff:"
    echo "        --spack-checkout ffffff"
    echo "      To checkout the 'v0.16' tag:"
    echo "        --spack-checkout tag:v0.16"
    echo "      Environment Variable: TCE_SPACK_CHECKOUT"
    echo ""
    echo "  --path-len <num>"
    echo "      The length for the install directory path. Long paths are"
    echo "      needed to ensure that there's enough room for build cached files"
    echo "      to be made relocatable. A path of an exact length is needed to"
    echo "      ensure this true across ci triggered builds."
    echo "      Environment Variable: TCE_PATH_LEN"
    echo "      Default: $install_path_len"
    echo ""
    echo "  -h|--help"
    echo "      Print this help info."
    echo ""
}

red="\e[0;31m"
green="\e[0;32m"
yellow="\e[0;33m"
#blue="\e[0;34m"
#teal="\e[0;35m"
#gray="\e[0;36m"
#bold="\e[1m"
reset="\e[0m"

function warning() {
    echo ""
    msg "${yellow}" "WARNING: $1"
    echo ""
}

function error() {
    echo ""
    msg "${red}" "ERROR: $1"
    echo ""
}

function error_exit() {
    error "$1"
    check_perms "$install_dir" "$shared_group"
    exit 1
}

function msg() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${reset}"
}

function status() {
    msg "$green" "process.sh: $1"
}

# If src and dst differ, backup dst in a date marked file before overwriting.
function backup_copy() {
    local src=$1
    local dst=$2

    if [[ -z $src ]]; then
        error_exit "Trying to backup_copy an empty src argument."
    fi
    if [[ -z $dst ]]; then
        error_exit "Trying to backup_copy to an empty dst argument."
    fi

    local backup_dir
    backup_dir=$(dirname "$dst")/.backups

    mkdir -p "${backup_dir}"
    echo "Backup copying $src to $dst"
    if [[ -e "$dst" ]] && diff -r "$src" "$dst" > /dev/null; then
        echo "Diff."
        cp -RL  "$dst" "${backup_dir}/${dst##*/}-$(date +'%Y-%m-%dT%H:%M:%S%z')"
    fi

    rm -rf "$dst"
    cp -RL --remove-destination "$src" "$dst"
}

function make_log() {
    # Given a log directory path (arg 1) and a log file name (arg 2),
    # find the next log file to create.  The path is saved in $make_log_path.
    local log_path="$1"
    mkdir -p "$log_path"
    local log_name="$2"
    local log_num=0
    if ls -1 "${log_path}/${log_name}".*.log &> /dev/null; then
        log_num=$(find "${log_path}" -name "${log_name}.*.log" | \
                  awk -F. '{ print $(NF-1) }' | sort -n | tail -1)
    fi
    mkdir -p "$log_path"
    log_num=$(( log_num + 1 ))
    make_log_path="${log_path}/${log_name}.${log_num}.log"
}

# We use a ticket system to do multiprocessing when creating the buildcache.
# To use tickets to multiprocess a function:
# 1. Call take_ticket
# 2. Call and background the function
# 3. In the function, before returning, call make_ticket
# 4. After all calls of the function have been issued, call wait_tickets.
TICKET_DIR=$(mktemp -d)
TICKET_COUNT=10
function make_ticket() {
    # Create a ticket. Tickets are essentially an empty file in the ticket directory.
    touch $TICKET_DIR/$(uuidgen -r)
}

function take_ticket() {
    # Take a ticket. If there are no tickets, wait for one to be available.
    while true; do
        for ticket in $(ls -1 $TICKET_DIR); do 
            rm $TICKET_DIR/$ticket
            return 
        done
        sleep 0.5
    done
}

function wait_tickets() {
    # Wait for all tickets to be returned

    for i in $(seq $TICKET_COUNT); do
        take_ticket
    done
}

# Setup all the initial tickets
for i in $(seq $TICKET_COUNT); do
    make_ticket
done

# Function to checkout a particular git reference for a git repository. Must
# already be inside the directory of the git repository.
# Usage:
# repo_checkout [tag:]REF
# The use of 'tag:' tells the function to use the git checkout options for
# tags.
# Return values:
# - 0: Success
# - 1: Failure
function repo_checkout () {
    local ref="$1"
    local checkout_opts
    local checkout_ref
    echo "$ref"
    if [[ $ref = "tag:"* ]]; then
        checkout_opts='-t'
        checkout_ref="${ref#tag:}"
    else
        checkout_opts=''
        checkout_ref="${ref}"
    fi
    if ! git fetch -f --all --tags; then
        error "Error fetching tags for repo."
        return 1
    fi
    # Shellcheck is disabled because we do want word splitting when expanding
    # checkout_opts. Otherwise, an null string is passed as an argument that
    # git doesn't know what to do with. This way, just white space is passed.
    # User input should never be allowed in checkout_opts.
    # shellcheck disable=2086
    if ! git checkout $checkout_opts "$checkout_ref"; then
        echo "$checkout_opts  $checkout_ref"
        error "Error checking out reference $ref."
        return 1
    fi
}

# Function to verify a particular git reference for a git repository. Must
# already be inside the directory of the git repository.
# Usage:
# repo_validate [tag:]REF
# The use of 'tag:' tells the function to use the git checkout options for
# tags.
# Return values:
# - 0: Success
# - 1: Failure
function repo_validate () {
    local ref="$1"
    local checkout_opts
    local checkout_ref
    echo "$ref"
    if [[ $ref = "tag:"* ]]; then
        checkout_opts='-t'
        checkout_ref="${ref#tag:}"
        if ! [[ $(git describe --tags) == "$checkout_ref" ]] ; then
            error "Error validating reference $ref."
            return 1
        fi
    else
        checkout_opts=''
        checkout_ref="${ref}"
        if ! [[ $(git rev-parse HEAD) =~ $checkout_ref || $(git rev-parse --abbrev-ref HEAD) =~ $checkout_ref ]] ; then
            error "Error validating reference $ref."
            return 1
        fi
    fi
}

# This will set the permissions of the specified directory
# If a group is specified: g+wrX,a+rX
# If a group is NOT specified: a+rX
# Usage: check_perms dir_name <group_name>
# - arg1 [required] : name of the target directory
# - arg2 [optional] : name of the group for setting permissions
function check_perms () {
    local target_dir=$1
    local group=$2

    status "Running: check_perms $target_dir $group"
    shopt -s dotglob
    if [[ -n $group ]]; then
        chgrp -Rf "$group" "$target_dir" &>/dev/null &
        find "$target_dir" -type d -exec chmod g+s {} + &>/dev/null &
        chmod -Rf g+wrX,a+rX "$target_dir" &>/dev/null &
    else
        chmod -Rf a+rX "$target_dir" &>/dev/null &
    fi
    wait
}

# This will create a signal trap that will run a specified command and exit with the number specified by the signal
# Usage: cmd cmd_args...
# - arg1: The command to be executed
# - arg2: List of arguments to be passed to the command specified in arg1
#
# NOTE: When trapping a signal the normal signal behavior is CHANGED
#       For example, if you trap a SIGILL it will not core dump!
function trap_with_exit () {
    local cmd=$1; shift
    local cmd_args=$*
    local base_err=128

    local sig_num=0
    local sig_exit=0
    for signal in "${TRAP_SIGNALS[@]}"; do
        sig_num=$(kill -l "$signal")
        sig_exit=$(( base_err + sig_num ))
        trap '${cmd} ${cmd_args[*]}; wait ; exit ${sig_exit}' "$signal"

    done
}

# Parse options
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -C|--cache-only)
        echo "Cacheonly=true"
        cacheonly=true
        shift
        ;;
    -R|--reindex)
        echo "Reindex=true"
        reindex=true
        shift
        ;;
    # Only reconcretize if requested
    -c|--concretize)
        echo "Concretize=true"
        concretize=true
        shift # past argument
        ;;
    # Debug mode
    -d|--debug)
        echo "Debug=True"
        set -x
        shift # past argument
        ;;
    -f|--facility)
        shift # past argument
        facility=$1
        echo "Facility=$facility"
        shift
        ;;
    -e|--environment)
        shift # past argument
        environment_name=$1
        echo "Environment=$environment_name"
        shift
        ;;
    -r|--release)
        shift
        release_name=$1
        echo "Release=$release_name"
        shift
        ;;
    -l|--licenses)
        shift
        license_dir=$1
        echo "License Directory=$license_dir"
        shift
        ;;
    -i|--install-prefix)
        shift # past argument
        install_dir=$1
        echo "Install Prefix=$install_dir"
        shift
        ;;
    -m|--module)
        echo "Module Generation=True"
        module=true
        shift # past argument
        ;;
    -D|--delete-module-tree)
        echo "Module Tree Deletion=True (Module Generation=True)"
        module=true
        delete_tree="--delete-tree"
        shift # past argument
        ;;
    # Set to greater than zero to use compute nodes in an allocation to
    # parallelize the build.  Jobs will be launched for the time limit
    # specified and on the number of nodes specified by this variable. A job
    # will launch and either complete or time-out.  If, once a job has ended,
    # the process on the front-end node is still running, another job will be
    # submitted to the scheduler.  This continues until the install process on
    # the front-end has completed and the script will continue on to the next
    # section.
    -p|--parallel)
        shift # past argument
        num_nodes="$1"
        echo "Number of Nodes=$num_nodes"
        shift
        ;;
    -b|--buildcache)
        shift
        build_cache="$1"
        echo "Build cache=${build_cache}"
        shift
        ;;
    --prod-buildcache)
        shift
        prod_buildcache=true
        echo "Uploading buildcache to production buildcache"
        ;;
    --cert-store)
        shift
        cert_store="$1"
        echo "Cert store=${cert_store}"
        shift
        ;;
    --no-buildcache-upload)
        shift
        buildcache_upload=false
        echo "Disabling buildcache upload to pe-serve"
        ;;
    --skip-buildcache-on-failure)
        shift
        skip_buildcache_on_failure=true
        ;;
    -g|--shared_group)
        shift
        shared_group="$1"
        echo "Share group=${shared_group}"
        shift
        ;;
    --ignore-cache)
        shift
        ignorecache=true
        echo "Ignoring buildcache for installations"
        ;;
    # Skip install if requested
    -s|--skip-install)
        echo "Install=false"
        skip_install=true
        shift # past argument
        ;;
    -B|--force-bootstrap)
        echo "Force Compiler Bootstrap=true"
        force_bootstrap=true
        shift # past argument
        ;;
    --stage)
        echo "Stage=true"
        stage=true
        shift # past argument
        ;;
    --no-stage)
        echo "No Stage=true"
        nostage=true
        shift # past argument
        ;;
    --root)
        shift
        install_root="$1"
        echo "Install Root=$install_root"
        shift
        ;;
    -t|--time-limit)
        shift # past argument
        time_limit="$1"
        echo "Allocation Time Limit=$time_limit"
        shift
        ;;
    -v|--verbose)
        shift
        verbose=true
        ;;
    --secret)
        shift
        secret_path=$1
        echo "Secret=$secret_path"
        shift
        ;;
    --public-key)
        shift
        public_key_path=$1
        echo "Public Key=$public_key_path"
        shift
        ;;
    -U|--user-spack-ok)
        shift
        user_spack_ok=true
        echo "User Spack OK=true"
        ;;
    # Allow the user to choose a specific reference to checkout for Spack
    --spack-checkout)
        shift # past argument
        spack_checkout=$1
        echo "Spack Checkout = $spack_checkout"
        shift
        ;;
    # Allow the user to specify a url from which to checkout Spack
    --spack-url)
        shift # past argument
        spack_url=$1
        echo "Spack URL=$spack_url"
        shift
        ;;
    --path-len)
        shift
        install_path_len=$1
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage
        error "Unknown option $1"
        exit 1
        ;;
esac
done

status "Checking required args."

# There are four required arguments from command line args or env variables:
# - facility
# - environment
# - release
# - install_dir
# There is only one argument that can NOT be found in a process.cfg file:
# facility. Deal with it now so that we can find process.cfg which may set any
# of the other possible environment variables.
facility=${facility:-${TCE_FACILITY}}

# Check that facility is specified, as this is required.
if [[ -z $facility ]]; then
    error_exit "A facility must be specified.  This can be done with the
environment variable TCE_FACILITY or with the --facility command line option."
fi

# Check for a relative path
if [[ $facility = */* ]] && ! [[ $facility = /* ]]; then
    error_exit "The facility value must be a non-path string or an absolute path.
The facility value looks to be a relative path:
$facility."
fi

if ! [[ $facility = /* ]]; then
    facility=$config_repo_root/facilities/$facility
fi

if ! [[ -d $facility ]]; then
    error "Facility '$facility' was specified, but the directory doesn't exist.
Change the facility specification or create the config directory.
Available facilities:"
    find "$config_repo_root/facilities" -maxdepth 1 -mindepth 1 -type d -printf "%P\n"
    exit 1
fi

# Construct the path to process.cfg and make sure it is there.
process_config=${facility}/process.cfg
if ! [[ -f ${process_config} ]]; then
    error_exit "Unable to find process.cfg in $facility"
fi

# Now, source process_config which can set other environment variables.
status "Sourcing config file 'process.cfg'."
# Shellcheck isn't able to look up dynamically determined sourced files. Since
# we aren't able to know until we run this script what process_config will be,
# there really isn't a way to satisfy shellcheck wanting to know what
# process_config is. So, disable that check.
# shellcheck disable=1090
if ! source "${process_config}"; then
    error_exit "Error in sourcing the process config file $process_config."
fi


environment_name=${environment_name:-${TCE_ENVIRONMENT}}
release_name=${release_name:-${TCE_RELEASE}}
release=${releases}/${release_name}
install_dir=${install_dir:-${TCE_INSTALL_DIR}}

# Now, deal with the rest of the required arguments.
if [[ -z $release_name ]]; then
    error_exit "A release must be specified.  This can be done with the
environment variable TCE_RELEASE or with the --release command line option."
fi

if [[ -z $environment_name ]]; then
    error_exit "An environment must be specified.  This can be done with the
environment variable TCE_ENVIRONMENT or with the --environment command line option."
fi

if ! [[ -d $release ]]; then
    error "Release $release does not exist in releases dir. Available releases:"
    find "${releases}" -maxdepth 1 -mindepth 1 -type d -printf "%P\n"
    exit 1
fi

# Find the release config file. 
release_config=${release}/config.sh
if ! [[ -f $release_config ]]; then
    error_exit "Could not find the release config file at ${release_config}."
fi
# shellcheck disable=1090
if ! source "${release_config}"; then
    error_exit "Error in sourcing the release config file."
fi

environments="${release}/environments"
environment="${environments}/${environment_name}"

if ! [[ -d $environment ]]; then
    error "Environment '$environment' does not exist. Available environments:"
    find "$environments" -maxdepth 1 -mindepth 1 -type d -printf "%P\n"
    exit 1
fi

# install_dir needs to be set
if [[ -z $install_dir ]]; then
    error_exit "An installation prefix must be specified.  This can be done with the
environment variable TCE_INSTALL_DIR or with the --install-prefix command line option."
fi

status "Checking optional args"

# Bring all of the optional args together in order of precedence:
# - command line args
# - environment variables (if it exists)
# - default values (if it exists)
license_dir=${license_dir:-${TCE_LICENSES}}
reindex=${reindex:-${reindex_def}}
concretize=${concretize:-${concretize_def}}
skip_install=${skip_install:-${skip_install_def}}
module=${module:=${module_def}}
stage=${stage:=${stage_def}}
force_bootstrap=${force_bootstrap:-${force_bootstrap_def}}
prod_buildcache=${prod_buildcache:-${prod_buildcache_def}}
cert_store=${cert_store:-${TCE_CERT_STORE:-${cert_store_def}}}
buildcache_upload=${buildcache_upload:-${buildcache_upload_def}}
ignorecache=${ignorecache:-${ignorecache_def}}
build_cache=${build_cache:-${TCE_BUILDCACHE}}
skip_buildcache_on_failure=false
shared_group=${shared_group:-${TCE_SHARED_GROUP:-${shared_group_def}}}
secret_path=${secret_path:-${TCE_SECRET}}
public_key_path=${public_key_path:-${TCE_PUBLIC_KEY}}
install_path_len=${install_path_len:-${TCE_PATH_LEN:-${install_path_len_def}}}
spack_url=${spack_url:-${TCE_SPACK_URL:-${spack_url_def}}}
spack_checkout=${spack_checkout:-${TCE_SPACK_CHECKOUT}}
verbose=${verbose:-${verbose_def}}
num_nodes=${num_nodes:-${TCE_NUM_NODES:-${num_nodes_def}}}
time_limit=${time_limit:-${TCE_TIME_LIMIT:-${time_limit_def}}}

# Run some checks on the optional args so that we can error out early if
# needed.

# Some checks against install_dir will be needed, and those will be easier if
# the trailing slash is removed.
install_dir=${install_dir%/}


# There are a few things to check when doing a buildcache
if [[ -n $build_cache ]]; then
    # Set install_root appropriately if not set already
    if [[ -z "${install_root}" ]]; then
        install_root="\$spack/.."
    fi

    if [[ -z $cert_store ]]; then
        error_exit "Specified buildcache without providing --cert-store"
    fi

    # Derive the signing key paths from the cert store if not otherwise specified.
    if [[ -z $secret_path ]]; then
        secret_path=$cert_store/secring.gpg
    fi

    if [[ -z $public_key_path ]]; then
        public_key_path=$cert_store/pubring.gpg
    fi

    # Make sure all cert paths exist.
    if ! [[ -e ${cert_store} ]]; then 
        error_exit "Specified cert_store does not exist at given path '${cert_store}'"
    fi

    if ! [[ -e ${secret_path} ]]; then
        error_exit "Secret key does not exist at '${secret_path}'"
    fi
    
    if ! [[ -e ${public_key_path} ]]; then
        error_exit "Public key does not exist at '${public_key_path}'"
    fi

    # Check for the proper path length so that the created buildcaches are
    # usable in production.
    if ! [[ ${#install_dir} -eq ${install_path_len} ]]; then
        #TODO tgoetsch: rework to suggest a path with padding sufficient to pass check
        error_exit "Install path length '${#install_dir}' is incorrect for
buildcache generation. Need a path of exactly length ${install_path_len}.
The following path has a length of ${#install_dir}:
${install_dir}"
    fi
fi

# Only do modulefile generation if the concretization or installation stages
# are going to happen
if [[ $module = true ]] && \
    [[ $concretize = false ]] && \
    [[ $skip_install = true ]]; then
    error_exit "Modulefile generation requires either of the concretize or install
stages to be run, but it looks like both of those stages will be skipped.
Please enable at least one of those stages."
fi


# Check for user spack config files
if find "$HOME/.spack/" -name "*.yaml" &>/dev/null && [[ "$user_spack_ok" != true ]]; then
    msg "$yellow" "A ~/.spack directory was detected. Using a temp directory as \$HOME instead. 
If you want to use your ~/.spack directory, use the '--user-spack-ok' option."
    HOME=$install_dir
    export HOME
fi

# Check for hugepages modulefiles
#TODO tgoetsch: ask if this check should only be done on a Cray
if [[ ${_LMFILES_} =~ hugepages ]] || [[ ${LOADEDMODULES} =~ hugepages ]] ; then
    error_exit "Detected a hugepages modulefile in your environment.  This will most
certainly cause issues with certain packages building on a Cray.  Unload the module
and try again."
fi

if [[ $verbose == true ]]; then
    export SPACK_VERBOSE=(-d)
else
    export SPACK_VERBOSE=()
fi

# Figure out environment specific install dir.
#TODO tgoetsch: is there a cleaner way to generate the install_env for the 
#               buildache, without chopping the environment name in the path? 
#               Maybe have spack assess the full path requirement (buildcache/
#               install_dir/inst_env_name) and suggest an appropriate path 
#               length. If the buildcache path is too long without any padding.
#               .... IDK

if [[ -n $build_cache ]]; then
    # When generating the build cache, the prefix must be the same
    # length to ensure binary cached builds will always be relocatable.
    inst_env_name=$(echo "${environment_name}__________" | cut -c -9)
else
    inst_env_name=${environment_name}
fi
install_dir="${install_dir}/${inst_env_name}"

# At this point, configuration for this script is done. It is time to start
# doing work.

# Set up traps in case a signal is sent at this point
trap_with_exit "check_perms" "$install_dir" "$shared_group"

status "Set up install directory at ${install_dir}"

# Create the installation directory
if [[ ! -d ${install_dir} ]]; then
    if ! mkdir -p "${install_dir}"; then
        error_exit "Unable to create $install_dir"
    fi
fi

# Figure out the log directory and create it
log_dir="${install_dir}/logs"
if [[ ! -d ${log_dir} ]]; then
    if ! mkdir -p "${log_dir}"; then
        error_exit "Unable to create log directory $log_dir"
    fi
fi

hist_script=${install_dir}/history/process.sh
backup_copy "${BASH_SOURCE[0]}" "${hist_script}"

# If there is no Spack installation in the installation directory, clone it.
spack_root="${install_dir}/spack"
#TODO tgoetsch: should the repo log belong in the user's home directory?
spack_repo_log=$(mktemp ~/.process.spack_log.XXXXXXXX)
spacklemore_root=${install_dir}/spacklemore

# test for nostage, and either validate or clone/checkout ref
if [[ "$nostage" = true ]]; then
    status "No-stage was specified, therefore will not clone, fetch or checkout Spack's Repo"
    # if there's no Spack repo in $spack_root, fail
    if [[ ! -d "${spack_root}" ]]; then
        error "Spack root $spack_root doesn't exist!"
    else
        pushd "${spack_root}" &>/dev/null
    fi
    if false ; then # -n ${spack_checkout} ]] ; then
        status "Validating Spack git reference ${spack_checkout} against ${spack_root}"
        if ! repo_validate "$spack_checkout" &>> "${spack_repo_log}"; then
            error_exit "Error validating ${spack_checkout} in ${spack_root}. See ${spack_repo_log}"
        fi
        popd &>/dev/null
    fi
    rm "${spack_repo_log}"

    status "No-stage was specified, therefore will not clone, fetch or checkout Spacklemore's Repo"
    if [[ ! -d ${spacklemore_root} ]]; then
        error "Spacklemore root ${spacklemore_root} doesn't exist!"
    fi
else
    status "Setting up Spack repo in install directory"

    # If there is no Spack installation in the installation directory, clone it.
    if [[ ! -d "${spack_root}" ]]; then
        status "Cloning Spack from ${spack_url} into ${spack_root}"
        #TODO tgoetsch: potentially replace with a check using wget and error_exit?
        if ! git clone "${spack_url}" "${spack_root}" &>> "${spack_repo_log}"; then
            error_exit "Unable to checkout spack repository from $spack_url. See ${spack_repo_log}"
        fi
    fi
    # If a reference has been passed to checkout in the spack repo, now is the time to do it.
    if [[ -n "${spack_checkout}" ]]; then
        status "Checking out Spack git reference $spack_checkout"
        pushd "${spack_root}" &>/dev/null
        if ! repo_checkout "$spack_checkout" &>> "${spack_repo_log}"; then
            error_exit "Error checking out $spack_checkout in ${spack_root}. See ${spack_repo_log}"
        fi
        popd &>/dev/null
    fi

    status "Setting up spacklemore repo in install directory"
    rm -rf "${spacklemore_root}"
    mkdir -p "${spacklemore_root}"
    #TODO tgoetsch: add check that copy works
    cp -R "${spacklemore}" "${install_dir}"
fi

# Move the environment/release into the spack environments directory.
release_env=${spack_root}/var/spack/environments/${release_name}

# Copy the release environment
echo "Release $release"
echo "Release_env $release_env"
echo "Copying $environment to $release_env"
backup_copy "$environment" "$release_env"

pushd "$facility" &>/dev/null
# Copy in the appropriate configs for Spack.
for file in  *.yaml; do
    backup_copy "$file" "$spack_root/etc/spack/$file"
done

spack_config=$spack_root/etc/spack/config.yaml
if [[ -n "${install_root}" ]]; then
    "${config_repo_root}/bin/line_edit" -i "${spack_config}" -o "${spack_config}" \
        'root:.*$' "root: ${install_root}"
fi
echo "install root: $install_root"

license_dest="$spack_root/etc/spack/licenses"
if [[ -z "$license_dir" ]]; then
    status "Copying licenses into install directory"

    if [[ -d "$license_dest" ]] && [[ -L "$license_dest" ]]; then
        error_exit "Refusing to copy licenses into a symbolic link dir to avoid overwriting system
        wide licenses"
    fi

    if [[ -d licenses ]]; then
        status "Copying license files"
        pushd "licenses" &>/dev/null
        # Copy in the appropriate licenses for packages that require them.
        for dir in *; do
            mkdir -p "${license_dest}/${dir}"
            for file in "$dir"/*; do
                backup_copy "$file" "${license_dest}/${file}"
            done
        done
        popd &>/dev/null # Out of licenses
    fi
else
    status "Symlinking to specified license dir."

    if [[ -d "$license_dest" ]] && ! [[ -L "$license_dest" ]]; then
        error_exit "Refusing to replace license dir with a symbolic link."
    fi

    # Replace the existing symlink
    ln -s -f  "${license_dir}" "${license_dest}"
fi
popd &>/dev/null # Out of facility

status "Set up Spack"

# Set up spack
# Shellcheck doesn't like dynamically determined files to source.
# shellcheck disable=1091,1090
. "${spack_root}/share/spack/setup-env.sh"

status "Update the config environment"

# Run update for the config/environment
if [ -f "${spack_root}/etc/spack/config.yaml.bkp" ]; then
    rm "${spack_root}/etc/spack/config.yaml.bkp"
fi

spack config --scope=site update config -y

SPACK_CACHING=--use-cache

# Set up the public key for binary packages
#TODO tgoetsch: Checks earlier make sure that public_key_path exists, so
#               can we get rid of this part of the following check?
if [[ -n ${public_key_path} && $ignorecache = false ]]; then
    status "Setting up the public key"
    if ! spack gpg trust "${public_key_path}" &>/dev/null ; then
        error_exit "Error trusting public key at '${public_key_path}'"
    fi
else
    # Disable the cache in the absence of a public key
    SPACK_CACHING=--no-cache
fi

if [ "$cacheonly" = true ]; then
    SPACK_CACHING=--cache-only
fi

# no matter what SPACK_CACHING is set to, export it.
export SPACK_CACHING

if [ -f "./spack.yaml.bkp" ]; then
    rm "./spack.yaml.bkp"
fi

status "Updating and activating the spack environment release ${release_name}"
spack --stacktrace env update -y "${release_name}"

# Add the spacklemore repo for this deployment.
if [[ ! -f "${spack_root}/etc/spack/repos.yaml" ]]; then
    spack repo add --scope=site "${spacklemore_root}"
fi

status "Finding compilers"

# Run `spack compilers find --scope=site` in case this is the first time or there are
# new compilers.
if ! spack compiler find --scope=site ; then
    error_exit "'spack compiler find --scope=site' failed."
fi
spack compiler list

# Exit if the `--stage` flag was used.
if [[ $stage = true ]]; then
    echo ""
    status "Staging completed."
    status "Summary:"
    echo "  Installation type: $environment_name"
    echo "  Release version: $release_name"
    echo "  Installation directory: $install_dir"
    echo ""
    check_perms "$install_dir" "$shared_group"
    exit 0
fi

status "Activating Spack Environment"
if ! spack "${SPACK_VERBOSE[@]}" env activate -V "${release_name}"; then
    error_exit "Failed activating environment."
fi

# From here on out, don't use error_exit so that processing can continue. That
# will ensure a useful summary and that supplemental tasks can still be run
# even in the face of failure.

# An array to house valid status indicators
NOT_DONE="Not Done"
SUCCESSFUL="Successful"
FAILED="Failed"
SKIPPED="Skipped"
valid_statuses=( $NOT_DONE $SUCCESSFUL $FAILED $SKIPPED )
# Variables to track the status of the stages
bootstrap_stat=$NOT_DONE
reindex_stat=$NOT_DONE
concretize_stat=$NOT_DONE
install_stat=$NOT_DONE
build_cache_stat=$NOT_DONE
upload_buildcache_stat=$NOT_DONE
module_stat=$NOT_DONE
# Variable to track whether or not to continue doing each stage. This will
# allow continuing with execution of this script until the end.
build_continue=true

function do_reindex () {
    local log_path=$1

    status "Reindexing"
    spack clean -m
    status "Reindexing to $log_path"
    /usr/bin/time spack "${SPACK_VERBOSE[@]}" reindex |& tee "$log_path"
    local ret_val=$?

    if test "$ret_val" != 0 || grep -E '(^Traceback)|(==> Error)' "$log_path"; then
        return 1
    else
        return 0
    fi
}

function do_concretize() {
    local log_path=$1

    status "Cleaning long-lived caches."
    spack clean -m
    status "Concretizing to $log_path"
    /usr/bin/time spack --profile --stacktrace "${SPACK_VERBOSE[@]}" concretize --fresh -f |& tee "$log_path"
    local ret_val=$?

    if test "$ret_val" != 0 || grep -E '(^Traceback)|(==> Error)' "$log_path"; then
        return 1
    else
        return 0
    fi
}

status "Checking for compiler bootstrap script."
if [[ -e ${environment}/bootstrap_compilers.sh ]]; then
    bootstrap_stat=$SUCCESSFUL
    wrapper=${config_repo_root}/bin/wrapper.sh
    tmp_sum=$(mktemp)
    md5sum "${environment}/bootstrap_compilers.sh" > "${tmp_sum}"
    if [[ -e "${install_dir}/bootstrapped.md5" ]] &&
        [[ $(awk '{print $1}' "${install_dir}/bootstrapped.md5") == $(awk '{print $1}' "$tmp_sum") ]] &&
        [[ ${force_bootstrap} = false ]]; then

        status "Skipping compiler bootstrap script (already run)."
        bootstrap_stat=$SKIPPED
    else
        status "Running compiler bootstrap script."
        make_log "$log_dir" bootstrap
        bootstrap_log=$make_log_path

        # This ensures the db gets regenerated.
        spack find
        if ! "${wrapper}" "${environment}/bootstrap_compilers.sh" "$install_dir" \
                |& tee "$bootstrap_log"; then
            error "Running ${environment}/bootstrap_compilers.sh failed.
See $bootstrap_log"
            bootstrap_stat=$FAILED
            build_continue=false
        else
            mv "$tmp_sum" "${install_dir}/bootstrapped.md5"
            warning "Forcing concretization after bootstrapping."
            concretize=true
        fi
    fi
else
    warning "No ${environment}/bootstrap_compilers.sh script found.
Create one to bootstrap base compilers, if needed."
    bootstrap_stat=$SKIPPED
fi

# Reindex if option was provided
if [[ $build_continue = true ]]; then
    rendx_log=""
    if [[ $reindex = true ]]; then
        reindex_stat=$SUCCESSFUL
        status "Reindexing"
        make_log "$log_dir" rendx
        rendx_log=$make_log_path
        if ! do_reindex "$rendx_log"; then
            error "Reindexing failed.  See $rendx_log"
            reindex_stat=$FAILED
            build_continue=false
        fi
    else
        status "Skipping reindexing"
        reindex_stat=$SKIPPED
    fi
fi

# (Re)concretize only if the option was provided and we should keep going
if [[ $build_continue = true ]]; then
    if [[ $concretize = true ]]; then
        conc_log=""
        concretize_stat=$SUCCESSFUL
        status "Concretizing"
        make_log "$log_dir" conc
        conc_log=$make_log_path
        if ! do_concretize "$conc_log"; then
            error "Concretization failed.  See $conc_log"
            concretize_stat=$FAILED
            build_continue=false
        fi
    else
        status "Skipping Concretization"
        concretize_stat=$SKIPPED
    fi
fi

function do_install() {
    local log_path=$1

    /usr/bin/time spack --stacktrace "${SPACK_VERBOSE[@]}" install "$SPACK_CACHING" --reuse --no-checksum \
        --yes-to-all |& tee "$log_path"
    local ret_val=$?

    if test "$ret_val" != 0 || grep -q "^Traceback" "$log_path"; then
        return 1
    else
        return 0
    fi
}

# Run the install if we are to keep building and not told to skip installation.
if [[ $build_continue = true ]]; then
    if [[ $skip_install = false ]]; then
        inst_log=""
        make_log "$log_dir" inst
        inst_log=${make_log_path}
        install_stat=$SUCCESSFUL
        status "Installing"
        if ! do_install "$inst_log"; then
            error "Installation failed.  See $inst_log"
            install_stat=$FAILED
            build_continue=false
        fi
    else
        status "Skipping install step"
        install_stat=$SKIPPED
    fi
fi

# Skip the buildcache step
if [[ $build_continue = false ]] && [[ $skip_buildcache_on_failure = true ]]; then
    buildcache=
fi

# Collect output from generating binary packages here.
BUILDCACHE_OUTFILES=/tmp/$USER/buildcache_out
rm -rf ${BUILDCACHE_OUTFILES}
mkdir ${BUILDCACHE_OUTFILES}

function dump_buildcache_outfiles() {
    # Dump the buildcache outfiles to the log and screen.
    local outfile
    for outfile in $(ls -1 ${BUILDCACHE_OUTFILES}); do
        cat ${BUILDCACHE_OUTFILES}/$outfile
        cat ${BUILDCACHE_OUTFILES}/$outfile > ${buildcache_log}
        rm -f ${BUILDCACHE_OUTFILES}/$outfile
    done
}

function create_package() {
    # Create a binary package from the given spack hash.
    # Args:
    #   1 - Hash of package to create binary package of
    
    local tmpfile=$(mktemp)
    local package=$1

    spack find -lv "/$package" > $tmpfile 2>&1
    if ! spack "${SPACK_VERBOSE[@]}" buildcache create -m buildcache \
        --only package -a "/$package" > $tmpfile 2>&1 ; then
        error "Binary cache creation failed for $package. See $buildcache_log."
        buildcache_stat=${valid_statuses[2]}
    fi
    mv $tmpfile $BUILDCACHE_OUTFILES
    make_ticket
}

# Generate the build cache. Doing this doesn't depend on past stages being
# attempted or being successful. This could be building a buildcache of a
# previous run.
if [[ -n $build_cache ]]; then
    make_log "$log_dir" build_cache
    buildcache_log=${make_log_path}

    build_cache_stat=$SUCCESSFUL
    upload_buildcache_stat=$NOT_DONE

    # Initialize the signing key.
    status "Adding secret key"
    if ! spack gpg trust "$secret_path" |& tee "$buildcache_log"; then
        # If the key is already imported, this is fine.
        warning "Could not set up secret key from ${secret_path}"
    fi

    # Deactivating environment to pick up all built packages, not just those built for our
    # environment.
    #TODO tgoetsch: added this check for spack env deactivate, does spack need to die if this fails?
    status "Deactivating spack environment"
    if ! spack "${SPACK_VERBOSE[@]}" env deactivate; then
        error_exit "Failed to deactivate environment."
    fi

    status "Setting push url to ${build_cache}"
    spack mirror set-url buildcache --push --scope=site "${build_cache}"

    status "Generating build cache."
    for buildhash in $(spack find -lv | grep -vE '^==|^--|^ *$' | cut -c -7 | sort | uniq); do
        take_ticket
        create_package $buildhash &
        dump_buildcache_outfiles
    done

    wait_tickets
    dump_buildcache_outfiles

    if [[ $prod_buildcache = true ]]; then
        status "Moving development buildcache to production buildcache"
        mv $build_cache/build_cache $build_cache/build_cache-prod
    fi

    if [[ $buildcache_upload = false ]]; then
        status "Skipping buildcache upload to pe-serve."
        upload_buildcache_stat=$SKIPPED
    else
        status "Uploading buildcache to pe-serve."
        upload_tree=${config_repo_root}/bin/upload_tree.sh

        if ! "${upload_tree}" $cert_store $build_cache |& tee "$buildcache_log"; then
            upload_buildcache_stat=$FAILED
            error "Failed to upload buildcache changes to pe-serve. See $buildcache_log."
        fi
        upload_buildcache_stat=$SUCCESSFUL
    fi

    # Reactivating environment
    if ! spack "${SPACK_VERBOSE[@]}" env activate -V "${release_name}"; then
        error_exit "Failed to re-activate environment."
    fi
else
    status "Skipping the buildcache step"
    build_cache_stat=$SKIPPED
    upload_buildcache_stat=$SKIPPED
fi

# Run the module generation based on the type of install, if requested and if
# the build can continue. There was already a check to ensure either
# concretization or install were to happen in this run. If those failed, then
# this block of code won't be entered.
if [[ $build_continue = true ]]; then
    mod_log_list=""
    if [[ $module = true ]]; then
        module_stat=$SUCCESSFUL
        status "Generating modules"
        #TODO tgoetsch: if module gen has issues on the Cray Shasta systems, check this for bug
        if [[ "$environment_name" =~ linux-rhel7-x86_64_v3-* ||
            "$environment_name" =~ cray-sles15-* ]]; then
            mod_type="lmod"
        #    mod_list="utils toolchains toolchains-root"
        else
            mod_type="tcl"
        #    mod_list="defaults"
        fi
        mod_list="utils toolchains toolchains-root"
        for mod_name in $mod_list; do
            make_log "$log_dir" "$mod_name"
            if [[ -z $mod_log_list ]]; then
                mod_log_list=$make_log_path
            else
                mod_log_list="$mod_log_list $make_log_path"
            fi
            #only call --delete-tree once for utils, will delete and regenerate utils lmod: $spack/../modulefiles
            if [[ -n ${delete_tree} ]] && [[ "${mod_name}" == "utils" ]] ; then
                if ! /usr/bin/time spack "${SPACK_VERBOSE[@]}" module "${mod_type}" \
                   -n "$mod_name" refresh -y "${delete_tree}" |& tee "${make_log_path}" ; then
                    error "Module generation failed for $mod_name. See $make_log_path."
                    module_stat=$FAILED
                    build_continue=false
                    break
                fi
            elif ! /usr/bin/time spack "${SPACK_VERBOSE[@]}" module "${mod_type}" \
                 -n "$mod_name" refresh -y |& tee "${make_log_path}" ; then
                error "Module generation failed for $mod_name. See $make_log_path."
                module_stat=$FAILED
                build_continue=false
                break
            fi
        done
    else
        status "Skipping module generation"
        module_stat=$SKIPPED
    fi
fi

# Output summary of the run.
echo ""
status "Process complete."
status "Summary:"
echo "  Command used: $arg_set"
echo "  Installation type: $environment_name"
echo "  Installation directory: $install_dir"
echo "  Bootstrap: $bootstrap_stat"
if [[ $bootstrap_stat == "$SUCCESSFUL" || \
    $bootstrap_stat == "$FAILED" ]]; then
    echo "    See $bootstrap_log"
fi
echo "  Reindex: $reindex_stat"
if [[ $reindex_stat == "$SUCCESSFUL" || \
    $reindex_stat == "$FAILED" ]]; then
    echo "    See $rendx_log"
fi
echo "  Concretization: $concretize_stat"
if [[ $concretize_stat == "$SUCCESSFUL" || \
    $concretize_stat == "$FAILED" ]]; then
    echo "    See $conc_log"
fi
echo "  Installation: $install_stat"
if [[ $install_stat == "$SUCCESSFUL" || \
    $install_stat == "$FAILED" ]]; then
    echo "    See $inst_log"
fi
echo "  Local Buildcache Generation: $build_cache_stat"
if [[ $build_cache_stat == "$SUCCESSFUL" || \
    $build_cache_stat == "$FAILED" ]]; then
    echo "    See $buildcache_log"
fi
echo "  Upload to Remote Buildcache: $upload_buildcache_stat"
if [[ $upload_buildcache_stat == "$SUCCESSFUL" || \
    $upload_buildcache_stat == "$FAILED" ]]; then
    echo "    See $buildcache_log"
fi
echo "  Module Generation: $module_stat"
if [[ $module_stat == "$SUCCESSFUL" || \
    $module_stat == "$FAILED" ]]; then
    echo "    See the following logs:"
    for mod_log in $mod_log_list; do
        echo "      $mod_log"
    done
fi
echo ""

check_perms "$install_dir" "$shared_group"

if [[ $build_continue = true ]]; then
    exit 0
else
    exit 1
fi

