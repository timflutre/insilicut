#!/usr/bin/env bash

# Aim: report fragments when cutting genomic DNA with a restriction enzyme
# Copyright (C) 2014-2015 Institut National de la Recherche Agronomique (INRA)
# License: GPL-3+
# Persons: Timothée Flutre [cre,aut]
# Versioning: https://github.com/timflutre/insilicut

progVersion="1.0.1" # http://semver.org/

# Display the help on stdout.
# The format complies with help2man (http://www.gnu.org/s/help2man)
function help () {
  msg="\`${0##*/}' reports fragments when cutting genomic DNA with a restriction enzyme.\n"
  msg+="\n"
  msg+="Usage: ${0##*/} [OPTIONS] ...\n"
  msg+="\n"
  msg+="Options:\n"
  msg+="  -h, --help\tdisplay the help and exit\n"
  msg+="  -V, --version\toutput version information and exit\n"
  msg+="  -v, --verbose\tverbosity level (0/default=1/2/3)\n"
  msg+="      --gf\tpath to the file containing the genomic DNA (fasta format)\n"
  msg+="      --gn\tname of the genomic DNA (e.g. 'Athaliana')\n"
  msg+="      --ef\tpath to the file containing the restriction enzyme (fasta format)\n"
  msg+="      --en\tname of the enzyme (e.g. 'ApeKI')\n"
  msg+="      --ls\tlower bound on fragments size (default=100)\n"
  msg+="      --us\tupper bound on fragments size (default=300)\n"
  msg+="      --clean\tremove temporary files\n"
  msg+="      --p2i\tabsolute path to the insilicut directory (default="")\n"
  msg+="\t\tused for testing purposes only (e.g. in 'make check')\n"
  msg+="\n"
  msg+="Examples:\n"
  msg+="  ${0##*/} --gf Athaliana_genome.fa --gn Athaliana --ef ApeKI.fa --en ApeKI\n"
  msg+="\n"
  msg+="Remarks:\n"
  msg+="  if R is installed, a histogram of fragments size is also produced\n"
  msg+="\n"
  msg+="Report bugs to <timothee.flutre@supagro.inra.fr>."
  echo -e "$msg"
}

# Display version and license information on stdout.
# The person roles comply with R's guidelines (The R Journal Vol. 4/1, June 2012).
function version () {
  msg="${0##*/} ${progVersion}\n"
  msg+="\n"
  msg+="Copyright (C) 2014-2015 Institut National de la Recherche Agronomique (INRA).\n"
  msg+="License GPL-3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>\n"
  msg+="This is free software; see the source for copying conditions. There is NO\n"
  msg+="warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n"
  msg+="\n"
  msg+="Written by Timothée Flutre [cre,aut]."
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
	  TEMP=`getopt -o hVv:g:e: -l help,version,verbose:,gf:,gn:,ef:,en:,ls:,us:,clean,p2i: -n "$0" -- "$@"`
  else # original getopt is available (no long options, whitespace, sorting)
	  TEMP=`getopt hVv: "$@"`
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
      --gf) genomeFile=$2; shift 2;;
	    --gn) genomeName=$2; shift 2;;
      --ef) enzymeFile=$2; shift 2;;
	    --en) enzymeName=$2; shift 2;;
	    --ls) lowerSize=$2; shift 2;;
	    --us) upperSize=$2; shift 2;;
	    --clean) cleanTmp=true; shift;;
	    --p2i) pathToInsilicut=$2; shift 2;;
      --) shift; break;;
      *) echo "ERROR: options parsing failed, use -h for help"; exit 1;;
    esac
  done
  if [ -z "${genomeFile}" ]; then
    echo -e "ERROR: missing compulsory option --gf\n"
    help
    exit 1
  fi
  if [ ! -f "${genomeFile}" ]; then
    echo -e "ERROR: can't find file ${genomeFile}\n"
    help
    exit 1
  fi
  if [ -z "${genomeName}" ]; then
    echo -e "ERROR: missing compulsory option --gn\n"
    help
    exit 1
  fi
  if [ -z "${enzymeFile}" ]; then
    echo -e "ERROR: missing compulsory option --ef\n"
    help
    exit 1
  fi
  if [ ! -f "${enzymeFile}" ]; then
    echo -e "ERROR: can't find file ${enzymeFile}\n"
    help
    exit 1
  fi
  if [ -z "${enzymeName}" ]; then
    echo -e "ERROR: missing compulsory option --en\n"
    help
    exit 1
  fi
  if ! hash patman 2>/dev/null; then
	  echo -e "ERROR: can't find program 'patman' (https://bioinf.eva.mpg.de/patman/) in PATH\n"
	  exit 1
  fi
  if [ -z "${pathToInsilicut}" ]; then
	  if ! hash insilicut_extract_fragments.py 2>/dev/null; then
	    echo -e "ERROR: can't find program 'insilicut_extract_fragments.py' in PATH\n"
	    exit 1
	  fi
  else
	  pathToInsilicut="${pathToInsilicut}/scripts/"
	  if [ ! -f "${pathToInsilicut}insilicut_extract_fragments.py" ]; then
	    echo -e "ERROR: can't find program 'insilicut_extract_fragments.py' in package\n"
	    exit 1
	  fi
  fi
}

function run () {
  # step 1 ------------------------------------------------------------------
  if [ $verbose -gt "0" ]; then
	  echo -e "find all cut sites with patman..."
  fi
  tmpPrefix=out_patman_${genomeName}_${enzymeName}_e-0_g-0_a
  if [ ! -f "${tmpPrefix}.txt" ]; then
	  patman -P ${enzymeFile} -D ${genomeFile} -e 0 -g 0 -o ${tmpPrefix}.txt -a -s
  fi
  nbCutSites=$(wc -l < ${tmpPrefix}.txt)
  if [ $verbose -gt "0" ]; then
	  echo -e "nb of cut sites: "$nbCutSites
  fi
  
  if [ $nbCutSites -eq "0" ]; then
	  if $cleanTmp; then
	    rm -f ${tmpPrefix}.txt
	  fi
  else
	  # step 2 ------------------------------------------------------------------
	  if [ $verbose -gt "0" ]; then
	    echo -e "convert output into BED format (with AWK)..."
	  fi
	  if [ ! -f "${tmpPrefix}.bed.gz" ]; then
	    cat ${tmpPrefix}.txt | awk -F "\t" '{print $1"\t"$3-1"\t"$4"\t"$2"\t1000\t"$5}' | gzip > ${tmpPrefix}.bed.gz
	  fi
	  if $cleanTmp; then
	    rm -f ${tmpPrefix}.txt
	  fi
	  
	  # step 3 ------------------------------------------------------------------
	  if [ $verbose -gt "0" ]; then
	    echo -e "extract fragments (with Python)..."
	  fi
	  if [ ! -f "${tmpPrefix}_frags.bed.gz" ]; then
	    ${pathToInsilicut}insilicut_extract_fragments.py -i ${tmpPrefix}.bed.gz -s ${lowerSize} -S ${upperSize} -v ${verbose} >& stdout_extract_fragments_${genomeName}_${enzymeName}_e-0_g-0_a_s-${lowerSize}_S-${upperSize}.txt
	    if [ $verbose -gt "0" ]; then
		    echo -e $(grep "nb of kept fragments" stdout_extract_fragments_${genomeName}_${enzymeName}_e-0_g-0_a_s-${lowerSize}_S-${upperSize}.txt)
		    echo -e "more details in file stdout_extract_fragments_${genomeName}_${enzymeName}_e-0_g-0_a_s-${lowerSize}_S-${upperSize}.txt"
	    fi
	  fi
	  if $cleanTmp; then
	    rm -f ${tmpPrefix}.bed.gz
	  fi
	  
	  # step 4 ------------------------------------------------------------------
	  if hash R 2>/dev/null; then
	    if [ $verbose -gt "0" ]; then
		    echo -e "plot histogram of kept fragment sizes (with R)..."
	    fi
	    cmd="x <- read.table(\"${tmpPrefix}_frags.bed.gz\", sep=\"\t\"); tmp <- x[,3] - x[,2]; pdf(\"hist_frags_${genomeName}_${enzymeName}_e-0_g-0_a_s-${lowerSize}_S-${upperSize}.pdf\"); hist(tmp[tmp <= quantile(tmp, 0.75)], main=\"${enzymeName} fragments on ${genomeName}\", xlab=\"fragment size (bp)\", breaks=\"FD\"); abline(v=${lowerSize}, lwd=2, col=\"red\"); abline(v=${upperSize}, lwd=2, col=\"red\"); dev.off()"
	    echo $cmd | R --vanilla --quiet >/dev/null 2>&1
	  fi
	  
  fi # nbCutSites > 0
}

verbose=1
genomeFile=""
genomeName=""
enzymeFile=""
enzymeName=""
lowerSize="100"
upperSize="300"
cleanTmp=false
pathToInsilicut=""
parseCmdLine "$@"

if [ $verbose -gt "0" ]; then
  startTime=$(timer)
  msg="START ${0##*/} ${progVersion} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
  msg+="\ncmd-line: $0 "$@ # comment if an option takes a glob as argument
  msg+="\ncwd: $(pwd)"
  echo -e $msg
fi

run genomeFile genomeName enzymeFile enzymeName lowerSize upperSize cleanTmp pathToInsilicut verbose

if [ $verbose -gt "0" ]; then
  msg="END ${0##*/} ${progVersion} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
  msg+=" ($(timer startTime))"
  echo $msg
fi
