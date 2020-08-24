#!/usr/bin/env bash

#
# fetches the list of currently installed packages and updates the progs.csv accordingly:
# 1. packages currently not installed are removed from progs.csv.
# 2. packages listed in progs.csv and currently installed are kept, including their description.
# 3. packages not listed in progs.csv but currently installed are added (in alphabetical order).
# 4. To set the appropriate tags for newly installed packages, this script uses `pacman -Qm` to filter
# for locally installed packages and sets the `A` tag accordingly. This is far from perfect, but the best I got.
# Furthermore, this script uses the PKGBUILD meta information to generate a defeault description for
# packages newly added to progs.csv.
# 

if [ $# == 0 ]; then
    echo -e \
"update-progs - update progs.csv with currently installed packages\n
Usage: [DRY=1] update-progs.sh <progs> [ignore-pattern]
\tDRY\t\tset this env variable to 1, if output should be printed to stdout instead (does not update progs.csv)
\tprogs\t\tpath to progs.csv file
\tignore-pattern\toptional regex string of packages to ignore"
    exit 1
fi

ignore_pattern=${2:-""}

# list of installed packages toghether with their description:
installed=$(paste <(pacman -Qet | awk '{print $1}') <(pacman -Qeti | grep 'Description' | cut -c19-))

result=$(awk \
-v ignore_pattern=$ignore_pattern \
' 
# the first file is progs.csv, the second file is the list of locally installed packages,
# the third one is the list of currently installed packages.

BEGIN {
    # current file number, starting with 1 (progs.csv)
    file_num=1
    # the number of lines of the previously read file:
    last_file_len=0
}

{
    # increase file number every time FNR was reset:
    if(FNR+last_file_len < NR) {
        last_file_len=NR-FNR
        file_num++
    }

    if(file_num==1){
        # for each line of progs.csv:
        # save the whole line under its line number and reference the line number with the name of the package
        original_lines[FNR]=$0
        packages[$2]=FNR
    } else if(file_num==2) {
        # for each line of locally installed tools, save its name:
        local_packages[$1]++
    } else {
        # we are in the third file, listing all currently installed packages and their description:
        if(ignore_pattern != "" && match($1, ignore_pattern)) {
            # ignore package if pattern was given and match was found
            next
        }
        if(packages[$1]) {
            # the package is listed in progs.csv, print the original line:
            print original_lines[packages[$1]]
        } else {
            # the package is new, print a line containing its name, description and the correct tag:
            if(local_packages[$1]) {
                tag="A"
            } else {
                tag=""
            }
            print tag "," $1 ",\""$2"\""
        }
    }
}
' \
FS="," \
<(cat $1 | tail -n +2) \
<(pacman -Qm | awk '{print $1}') \
FS="\t" \
<(echo "$installed") \
| sort -t, -k2)
    
# make sure to attach the original header and print the output either to stdout or the original progs.csv:
header=$(head -n1 $1)
output=$(cat <(echo "$header") <(echo "$result"))
if [[ -v DRY ]]; then
    echo "$output"
else
    echo "$output" > $1
fi
