#!/bin/bash
# extract YCSB stats from one or more DSI tarballs and reformat into a CSV file.
#

usage() { echo "Usage: $0 [-b benchmark] [-p <string>] [d <path>] file1.tgz..." 1>&2
	  echo "   -b benchmark (default:ycsb)" 1>&2;
	  echo "   -p prefix-label (default:\"\")" 1>&2;
	  echo "   -d output directory (default:.)" 1>&2;
	  echo "   file1.tgz may be a file path or a URL to DSI artifacts tarball; each tarball is treated as a run." 1>&2;
	  echo "Output format is <run-number>,[<prefix>,]<workload>,<metric>,<value>" 1>&2;
	  exit 1; }

outpath=`pwd`

while getopts ":p:d:" opt; do
	case "${opt}" in
		p)
			prefix=${OPTARG}
			;;
		d)
			outpath=P{OPTARG}
			[ ! -d "${outpath}" ] && echo "Directory ${outpath} does not exist." && usage
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND-1))

# extract files
runNumber=1
urlregex='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
for file in "$@"; do
	if [[ "${file}" =~ ${urlregex} ]]; then
		mkdir -p /var/tmp/$$
		realfile=`basename ${file}`
		(cd /var/tmp/$$; wget -cq "${file}"; if [ -f "${realfile}" ]; then mkdir -p "${outpath}/${runNumber}"; tar -xf ${realfile} -p --wildcards -C "${outpath}/${runNumber}" ./WorkloadOutput/reports-*/ycsb*/test_output.log; rm -rf /var/tmp/$$; fi)
	else
		if [ -f "${file}" ]; then
			mkdir -p "${outpath}/${runNumber}";
			tar -xf ${file} -p --wildcards -C "${outpath}/${runNumber}" ./WorkloadOutput/reports-*/ycsb*/test_output.log;
		fi
	fi
	((runNumber++))
done

labelOverall=("\[OVERALL\]" \
              "RunTime\(ms\)" \
              "Throughput\(ops\/sec\)")
labelRead=("\[READ\]" \
	   "Operations" \
	   "AverageLatency\(us\)" \
	   "MinLatency\(us\)" \
	   "MaxLatency\(us\)" \
	   "95thPercentileLatency\(us\)")
labelUpdate=("\[UPDATE\]" \
	   "Operations" \
	   "AverageLatency\(us\)" \
	   "MinLatency\(us\)" \
	   "MaxLatency\(us\)" \
	   "95thPercentileLatency\(us\)")
	     
joiner=""
grepstr=""
for ((i=1; i<${#labelOverall[@]}; i++)); do
	if [ ! -z "${grepstr}" ]; then
		joiner="|"
	fi 
	grepstr="${grepstr}${joiner}${labelOverall[0]}, ${labelOverall[${i}]}"
done
for ((i=1; i<${#labelRead[@]}; i++)); do
	grepstr="${grepstr}|${labelRead[0]}, ${labelRead[${i}]}"
done
for ((i=1; i<${#labelUpdate[@]}; i++)); do
	grepstr="${grepstr}|${labelUpdate[0]}, ${labelUpdate[${i}]}"
done

prefixcomma="";
if [ ! -z "${prefix}" ]; then
	prefixcomma="${prefix},"
fi
for ((run=1; run<${runNumber}; run++)); do
	# egrep -H "${grepstr}" ${run}/WorkloadOutput/reports*/*/test_output.log
	# egrep -H "${grepstr}" ${run}/WorkloadOutput/reports*/*/test_output.log | awk -v PREFIX="${prefixcomma}" -F'[/\:,]' '/,/{gsub(/ /, "", $10); gsub(/[\[\]]/, "", $9); print PREFIX $1 "," $7 "," $9 "-" $10 "," $11}'
	egrep -H "${grepstr}" ${run}/WorkloadOutput/reports*/*/test_output.log | gawk -v PREFIX="${prefixcomma}" '{ match($0, /(^[0-9]+)\/WorkloadOutput\/[^\/]+\/([a-zA-Z0-9_\-]+)\/test_output\.log:([^,]+),\s*([^,]+),\s*(.*)/, arr); gsub(/[[\]]/, "", arr[3]); print arr[1] "," PREFIX arr[2] "," arr[3] "-" arr[4] "," arr[5] }'
done

