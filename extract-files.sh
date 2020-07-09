#!/usr/bin/env bash
#################################################################################
# Name: extract-files.sh                                                        #
# Author: Franklin Henriquez                                                    #
# Date: 08Jul2020                                                               #
# Description: Script extracts if no media files found.                         #
#                                                                               #
#################################################################################

# Required binaries:
# - bash v4+
#

# Notes:
# This script uses assossiated arrays which were introduce in bash v4.
#
__version__="0.0.1"
__author__="Franklin Henriquez"
__email__="franklin.a.henriquez@gmail.com"

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"

# Color Codes
# Reset
Color_Off='\033[0m'       # Text Reset
NC='\e[m'                 # Color Reset
# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White


# DESC: What happens when ctrl-c is pressed
# ARGS: None
# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT


function ctrl_c() {
    info "Trapped CTRL-C signal, terminating script"
    logger "\n================== $(date +'%Y-%m-%d %H:%M:%S'): Run Interrupted  ==================\n"
    rm -f ${TEMP_FILE}
    exit 2
}


# Setting up logging
exec 3>&2 # logging stream (file descriptor 3) defaults to STDERR
verbosity=3 # default to show warnings
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
inf_lvl=4
dbg_lvl=5
bash_dbg_lvl=6

notify() { log $silent_lvl "${Cyan}NOTE${Color_Off}: $1"; } # Always prints
critical() { log $crt_lvl "${IRed}CRITICAL:${Color_Off} $1"; }
error() { log $err_lvl "${Red}ERROR:${Color_Off} $1"; }
warn() { log $wrn_lvl "${Yellow}WARNING:${Color_Off} $1"; }
info() { log $inf_lvl "${Blue}INFO:${Color_Off} $1"; } # "info" is already a command
debug() { log $dbg_lvl "${Purple}DEBUG:${Color_Off} $1"; }

log() {
    if [ "${verbosity}" -ge "${1}" ]; then
        datestring=$(date +'%Y-%m-%d %H:%M:%S')
        # Expand escaped characters, wrap at 70 chars, indent wrapped lines
        echo -e "$datestring - __${FUNCNAME[2]}__  - $2" >&3 #| fold -w70 -s | sed '2~1s/^/  /' >&3
    fi
}

logger() {
    if [ -n "${LOG_FILE}" ]
    then
        echo -e "$1" >> "${log_file}"
        #echo -e "$1" >> "${LOG_FILE/.log/}"_"$(date +%d%b%Y)".log
    fi
}


audio_file_ext=""
image_file_ext=""
video_file_ext="
3g2
3gp
amv
asf
avi
drc
f4a
f4b
f4p
f4v
flv
gif
gifv
m2v
m4p
m4v
mkv
mng
mov
mp2
mp4
mpe
mpeg
mpg
mpv
mxf
net
nsv
ogg
ogv
rmvb
roq
svi
vob
webm
wmv
yuv
"

# DESC: Usage help
# ARGS: None
usage() {
    echo -e "\
    \rUsage: $0 -f <category>
    \rDescription: Extracts if no media files found

    \rrequired arguments:
    \r-f, --file-ext <category>\t Categories: all, audio, image, video
    \r                          \t          (default: all)

    \roptional arguments:
    \r-h, --help\t\t Show this help message and exit.
    \r-l, --log <file>\t Log file.
    \r-x, --example\t\t Show support file types.
    \r-v, --verbose\t\t Verbosity.
    \r             \t\t -v info
    \r             \t\t -vv debug
    \r             \t\t -vvv bash debug"

    return 0
}


# DESC: File Example
# ARGS: None
example_file () {

    echo -e "
    \rAudio:\r${audio_file_ext}

    \rImage:\r${image_file_ext}

    \rVideo:\r${video_file_ext}
    "
    return 0
}

# DESC: Parse arguments
# ARGS: main args
function parse_args() {

    local short_opts='f:,h,l:,v,x'
    local long_opts='example,file-ext:,help,log,verbose'

    # -use ! and PIPESTATUS to get exit code with errexit set
    # -temporarily store output to be able to check for errors
    # -activate quoting/enhanced mode (e.g. by writing out “--options”)
    # -pass arguments only via   -- "$@"   to separate them correctly
    ! PARSED=$(getopt --options=${short_opts} --longoptions=${long_opts} --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        # e.g. return value is 1
        #  then getopt has complained about wrong arguments to stdout
        debug "getopt has complained about wrong arguments"
        exit 2
    fi
    # read getopt’s output this way to handle the quoting right:
    eval set -- "$PARSED"

    if [[ "${PARSED}" == " --" ]]
    then
        debug "No arguments were passed"
        usage
        exit 1
    fi

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in

            -f | --file-ext)
                category="$2"
                shift 2
                ;;
            -l | --log)
                LOG_FILE="$2"
                log_file="${LOG_FILE/.log/}"_"$(date +%d%b%Y)".log
                shift 2
                ;;
            -h | --help )
                # Display usage.
                usage
                exit 1;
                ;;
            -x | --example)
                # Display exmaple.
                example_file
                exit 1;
                ;;
           -v | --verbose)
                (( verbosity = verbosity + 1 ))
                if [ $verbosity -eq $bash_dbg_lvl ]
                then
                    DEBUG="true"
                fi
                shift
                ;;
            -- )
                shift
                break ;;
            * )
                usage
                exit 3
        esac
    done

    return 0
}

# DESC: main
# ARGS: None
function main() {

    DEBUG="false"

    parse_args "$@"

    debug "Starting main script"

    if [ -z "${BASH_VERSINFO}" ] || [ -z "${BASH_VERSINFO[0]}" ] || [ ${BASH_VERSINFO[0]} -lt 4 ]
    then
        echo "This script requires Bash version >= 4"
        exit 3
    elif [ -z "${category}" ]
    then
        usage
    fi

    # Run in debug mode, if set
    if [ "${DEBUG}" == "true" ]; then
        set -o noclobber
        set -o errexit          # Exit on most errors (see the manual)
        set -o errtrace         # Make sure any error trap is inherited
        set -o nounset          # Disallow expansion of unset variables
        set -o pipefail         # Use last non-zero exit code in a pipeline
        set -o xtrace           # Trace the execution of the script (debug)
    fi

}

# make it rain
debug "Starting script"
main "$@"
debug "Script is complete"
logger "\n=========================================== $(date +'%Y-%m-%d %H:%M:%S'): Run Complete ===========================================\n"
exit 0
