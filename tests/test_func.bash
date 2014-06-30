#!/usr/bin/env bash

# Aim: launch a functional test for the insilicut package
# Copyright (C) 2014 Institut National de la Recherche Agronomique (INRA)
# License: GPL-3+
# Author: Timothée Flutre

progVersion="1.0"

# Display the help on stdout.
# The format complies with help2man (http://www.gnu.org/s/help2man)
function help () {
    msg="\`${0##*/}' launches a functional test for the insilicut package.\n"
    msg+="\n"
    msg+="Usage: ${0##*/} [OPTIONS] ...\n"
    msg+="\n"
    msg+="Options:\n"
    msg+="  -h, --help\tdisplay the help and exit\n"
    msg+="  -V, --version\toutput version information and exit\n"
    msg+="  -v, --verbose\tverbosity level (0/default=1/2/3)\n"
    msg+="  -i, --p2i\tabsolute path to the insilicut directory\n"
    msg+="  -n, --noclean\tkeep temporary directory with all files\n"
    msg+="\n"
    msg+="Report bugs to <timothee.flutre@supagro.inra.fr>."
    echo -e "$msg"
}

# Display version and license information on stdout.
function version () {
    msg="${0##*/} ${progVersion}\n"
    msg+="\n"
    msg+="Copyright (C) 2014 Institut National de la Recherche Agronomique (INRA).\n"
    msg+="License GPL-3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>\n"
    msg+="This is free software; see the source for copying conditions. There is NO\n"
    msg+="warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n"
    msg+="\n"
    msg+="Written by Timothée Flutre."
    echo -e "$msg"
}

# http://www.linuxjournal.com/content/use-date-command-measure-elapsed-time
function timer () {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local startRawTime=$1
        endRawTime=$(date '+%s')
        if [[ -z "$startRawTime" ]]; then startRawTime=$endRawTime; fi
        elapsed=$((endRawTime - startRawTime)) # in sec
        nbDays=$((elapsed / 86400))
        nbHours=$(((elapsed / 3600) % 24))
        nbMins=$(((elapsed / 60) % 60))
        nbSecs=$((elapsed % 60))
        printf "%01dd %01dh %01dm %01ds" $nbDays $nbHours $nbMins $nbSecs
    fi
}

# Parse the command-line arguments.
# http://stackoverflow.com/a/4300224/597069
function parseCmdLine () {
    getopt -T > /dev/null # portability check (say, Linux or Mac OS?)
    if [ $? -eq 4 ]; then # GNU enhanced getopt is available
	TEMP=`getopt -o hVv:i:n -l help,version,verbose:,p2i:,noclean \
        -n "$0" -- "$@"`
    else # original getopt is available (no long options, whitespace, sorting)
	TEMP=`getopt hVv:i:n "$@"`
    fi
    if [ $? -ne 0 ]; then
	echo "ERROR: "$(which getopt)" failed"
	getopt -T > /dev/null
	if [ $? -ne 4 ]; then
	    echo "did you use long options? they are not handled \
on your system, use -h for help"
	fi
	exit 2
    fi
    eval set -- "$TEMP"
    while [ $# -gt 0 ]; do
        case "$1" in
            -h | --help) help; exit 0; shift;;
            -V | --version) version; exit 0; shift;;
            -v | --verbose) verbose=$2; shift 2;;
            -i | --p2i) pathToInsilicut=$2; shift 2;;
	    -n | --noclean) clean=false; shift;;
            --) shift; break;;
            *) echo "ERROR: options parsing failed, use -h for help"; exit 1;;
        esac
    done
    if [ -z "${pathToInsilicut}" ]; then
        echo -e "ERROR: missing compulsory option --p2i\n"
        help
        exit 1
    fi
    if [ ! -d "${pathToInsilicut}" ]; then
        echo -e "ERROR: can't find directory ${pathToInsilicut}\n"
        help
        exit 1
    fi
}

function run () {
    cwd=$(pwd)
    cd "${pathToInsilicut}/tests"
    
    # step 1 ------------------------------------------------------------------
    if [ $verbose -gt "0" ]; then
	echo -e "prepare input data..."
    fi
    if [ ! -f "${pathToInsilicut}/tests/TAIR10_chr1.fas" ]; then
	if [ $verbose -gt "0" ]; then
	    echo -e "download chromosome 1 from A. thaliana..."
	fi
	wget ftp://ftp.arabidopsis.org/home/tair/Sequences/whole_chromosomes/TAIR10_chr1.fas
    fi
    echo -e ">ApeKI\nGCWGC" > ApeKI.fa
    
    # step 2 ------------------------------------------------------------------
    uniqId=$$ # process ID
    testDir=tmp_test_${uniqId}
    rm -rf ${testDir}
    mkdir ${testDir}
    cd ${testDir}
    if [ $verbose -gt "0" ]; then echo "temp dir: "$(pwd); fi
    
    # step 3 ------------------------------------------------------------------
    if [ $verbose -gt "0" ]; then
	echo -e "launch insilicut..."
    fi
    ${pathToInsilicut}/scripts/insilicut.bash --gf ../TAIR10_chr1.fas \
	--gn Atha --ef ../ApeKI.fa --en ApeKI -v $(expr ${verbose} - 1) \
	--p2i ${pathToInsilicut}
    
    # step 4 ------------------------------------------------------------------
    if [ $verbose -gt "0" ]; then
	echo -e "check outputs..."
    fi
    if [ $(zcat out_patman_Atha_ApeKI_e-0_g-0_a_frags_s-100_S-300.bed.gz | wc -l) != 5968 ]; then
	echo -e "test failed!"
	exit 1
    else
	echo -e "test passed!"
    fi
    
    # step 5 ------------------------------------------------------------------
    cd ${cwd}
    if $clean; then rm -rf "${pathToInsilicut}/tests/${testDir}"; fi
}

verbose=1
pathToInsilicut=""
clean=true
parseCmdLine "$@"

if [ $verbose -gt "0" ]; then
    startTime=$(timer)
    msg="START ${0##*/} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
    msg+="\ncmd-line: $0 "$@ # comment if an option takes a glob as argument
    msg+="\ncwd: $(pwd)"
    echo -e $msg
fi

run pathToInsilicut clean

if [ $verbose -gt "0" ]; then
    msg="END ${0##*/} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
    msg+=" ($(timer startTime))"
    echo $msg
fi
