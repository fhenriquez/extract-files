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
# - 7z
# - bunzip2
# - gunzip
# - tar
# - rar
# - uncompress
# - unzip

# Notes:
# This script uses assossiated arrays which were introduce in bash v4.
#
__version__="0.0.1"
__author__="Franklin Henriquez"
__email__="franklin.a.henriquez@gmail.com"

# Set magic variables for current file & dir
__cur_dir="$(pwd)"
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

# Extension to query
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

# To find file to extract
encryption_ext='.tar.bz2\|.tar.gz\|.bz2\|.rar\|.tar\|.gz\|.tbz2\|.tgz\|.zip\|.Z\|.7z'

# DESC: Usage help
# ARGS: None
usage() {
    echo -e "\
    \rUsage: $0 -f <category>
    \rDescription: Extracts files if no media file extension is found.

    \rrequired arguments:
    \r-d, --dir </path/to/dir>\t   Default: present working directory
    \r-f, --file-ext <category>\t   Categories: all, audio, image, video
    \r                          \t\t          (default: all)

    \roptional arguments:
    \r-h, --help\t\t Show this help message and exit.
    \r-l, --log <file>\t Log file.
    \r-r, --recursive\t\t Recursive checks (default: False).
    \r-x, --example\t\t Show support file types.
    \r-v, --verbose\t\t Verbosity.
    \r             \t\t -v   info
    \r             \t\t -vv  debug
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

    local short_opts=',d:,f:,h,l:,r,v,x'
    local long_opts=',dir:,example,file-ext:,help,log,recursive,verbose'

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

#    if [[ "${PARSED}" == " --" ]]
#    then
#        debug "No arguments were passed"
#        usage
#        exit 1
#    fi

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in

            -d | --dir)
                working_dir="$2"
                case ${working_dir} in
                      /*) debug "${working_dir} is absolute path" ;;
                       *) debug "${working_dir} is a relative path"
                           working_dir="${__cur_dir}/${2}"
                           debug "setting to ${working_dir}"
                           ;;
                    esac
                shift 2
                ;;
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
            -r | --recursive)
                recursive=true
                shift
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
# ARGS: file to extract
ex () {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       rar x $1       ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
        *)           debug "$1 cannot be extracted via extract()" ; return 1
        esac
    else
        debug "$1 is not a valid file"
        return 0
    fi

    return $(echo $?)
}


# DESC: check-file()
# ARGS: /path/to/file
function check-file() {

    if echo "${file}" | grep -iaF "sample" &> /dev/null
    then
        debug "Skipping ${file}, it is a sample file."
    elif [[ "${file}" =~ ".${extension}"$ ]]
    then
        debug "${extension} FOUND in ${file}"
        matched_files="${matched_files}${file},"
        found=true
    else
        debug "${extension} NOT FOUND in ${file}"
    fi

    return 0
}

# DESC: main
# ARGS: None
function main() {

    # Saving IFS as we need to change it later.
    OLD_IFS="${IFS}"

    DEBUG="false"
    matched_files=""
    found=false

    parse_args "$@"

    if ${recursive_run}
    then
        debug "\n ******** $(date +'%Y-%m-%d %H:%M:%S'): Starting Recursive Run ********"
    else
        debug "\n=========================================== $(date +'%Y-%m-%d %H:%M:%S'): Starting Run ===========================================\n"
    fi

    if [ -z "${BASH_VERSINFO}" ] || [ -z "${BASH_VERSINFO[0]}" ] || [ ${BASH_VERSINFO[0]} -lt 4 ]
    then
        echo "This script requires Bash version >= 4"
        exit 3
    elif [  -z "${category}" ]
    then
        category="all"
    elif [[ "${category}" == "all" || "${category}" == "audio" || "${category}" == "images" || "${category}" == "video" ]]
    then
        debug "Invalid category selected."
        usage
        exit 4
    fi

    if [ -z "${working_dir}" ]
    then
        working_dir=$__cur_dir
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

    info "Querying $working_dir for ${category} category."
    if [ "${category}" == "all" ]
    then
        category="${audio_file_ext}${image_file_ext}${video_file_ext}"
    fi

    for extension in $(echo ${category})
    do
        info "Processing ${extension}"
        # Setting IFS to ignore spaces, only count newlines.
        # Just in case there is a directory that contains spaces.
        IFS=$'\n'

        file_check=$(find ${working_dir} -maxdepth 1 -type f | wc -l)

        if [ ${file_check} -eq 0 ]  && ! ${recursive}
        then
            info "${working_dir} only contains directories and recursive: ${recursive}"
            return 0
        fi

        for file in $(ls "${working_dir}/")
        do
            if [ -d "${file}" ] && ${recursive}
            then
                debug "${file} is a directory, going inside to query"
                recursive_run=true
                # Make sure IFS returns to original value.
                IFS="${OLD_IFS}"
                main -d "${file}"
                debug "\n ******** $(date +'%Y-%m-%d %H:%M:%S'): Recursive Run Complete ********"
                recursive_run=false
            else
                check-file ${file}
            fi
#            if echo "${file}" | grep -iaF "sample" &> /dev/null
#            then
#                debug "Skipping ${file}, it is a sample file."
#            elif [[ "${file}" =~ ".${extension}"$ ]]
#            then
#                debug "${extension} FOUND in ${file}"
#                matched_files="${matched_files}${file},"
#                found=true
#            else
#                debug "${extension} NOT FOUND in ${file}"
#            fi
        done

        # Make sure IFS returns to original value.
        IFS="${OLD_IFS}"

    done

    if [ ${found} = true ]
    then
        info "Found Match:\n \r${matched_files::-1}"
    else
        # Setting IFS to ignore spaces, only count newlines.
        # Just in case there is a directory that contains spaces.
        IFS=$'\n'

        file=$(ls ${working_dir}/ | grep ${encryption_ext})
        info "No matches found, attempting to extract ${file}."

        # Make sure IFS returns to original value.
        IFS="${OLD_IFS}"

#        echo "${file}"
        if [[ "${file}" == '' ]]
        then
            info "No file found to extract."
            return 0
        else
            ex ${file}
            result=$(echo $?)
        fi

        if [ "${result}" = 0 ]
        then
            info "successfully extracted ${file}"
        else
            error "failed to extract ${file}"
        fi
    fi

    return 0
}

# make it rain
debug "Starting script"

recursive=false
recursive_run=false

main "$@"

debug "\n=========================================== $(date +'%Y-%m-%d %H:%M:%S'): Run Complete ===========================================\n"
exit 0
