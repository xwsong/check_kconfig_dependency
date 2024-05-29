#!/bin/bash

declare -a kconf_queue
declare -a kconf_visited
declare -a kconf_unset

function usage()
{
cat <<EOF
${scriptname} OPTIONS <path to source file> OPTIONS <path to source tree>

example: ckd.sh -f path/adc.c -s path/linux

Options:
    -f, --file      the file you want to check for
    -s, --source    the kernel source
    -h, --help      print this help text and exit
EOF
}

function parse_args()
{
    local scriptname=$(basename $0)
    while true; do
        case "${1}" in
        -f|--file)
            file=$2
            shift 2
            ;;
        -s|--source)
            source=$2
            shift 2
            ;;
        -h|--help)
            usage
            shift;
            exit 0;;
        *) break;;
        esac
    done
}

# get the relative path of source file
function get_relative_path()
{
# this function is from
# https://stackoverflow.com/questions/2564634/convert-absolute-path-into-relative-path-given-a-current-directory-using-bash
# both $1 and $2 are absolute paths beginning with /
# returns relative path to $2/$target from $1/$source
    local source=$1
    local target=$2
    local common_part=$source # for now

    result="" # for now

    while [[ "${target#$common_part}" == "${target}" ]]; do
        # no match, means that candidate common part is not correct
        # go up one level (reduce common part)
        common_part="$(dirname $common_part)"
        # and record that we went back, with correct / handling
        if [[ -z $result ]]; then
            result=".."
        else
            result="../$result"
        fi
    done

    if [[ $common_part == "/" ]]; then
        # special case for root (no common path)
        result="$result/"
    fi

    # since we now have identified the common part,
    # compute the non-common part
    forward_part="${target#$common_part}"

    # and now stick all parts together
    if [[ -n $result ]] && [[ -n $forward_part ]]; then
        result="$result$forward_part"
    elif [[ -n $forward_part ]]; then
        # extra slash removal
        if [[ ${forward_part:0:1} == '/' ]]; then
            result="${forward_part:1}"
        else
            result=$forward_part
        fi
    fi

    rel_file=$result
    if [ ! -f ${rel_file} ]; then
        echo "the file not exsit"
        exit 1
    fi
}

# get Makefile and Kconfig paths
function get_kconf_files()
{
    local rel_path=$(dirname $1)
    makefile=$rel_path/Makefile
    kconfig=$rel_path/Kconfig
    filename=$(basename $1)

    if [[ ! -f $makefile ]] || [[ ! -f $kconfig ]]; then
        echo "$makefile or $kconfig not exist"
    fi

    echo $makefile
    echo $kconfig
}

# add depedency configs to the queue
function add_kconf()
{
    kconf_queue+=($1)
}

# add depedency configs to the queue
function add_kconf_unset()
{
    local unset_kconf=${1:1}
    kconf_unset+=(CONFIG_$unset_kconf)
}

# find out the kernel option realted to the file
function check_conf()
{
    local file_object="${2%%.*}.o"
    local mf=$1
    # construct the pattern for CONFIG_***
    local pattern="(?<=\\$\()CONFIG_[_A-Z0-9]+(?=\)\s+\+=\s+$file_object)"
    local mul_objs_pattern="^[a-z]+(?=-y\s\+=\s.*$file_object)"

    match=$(grep -Po "$pattern" $mf)
    if [ "$match" != "" ]; then
        echo "The option is $match"
        add_kconf ${match:7}
    else
        echo "check_conf $mul_objs_pattern"
        match=$(grep -Po "$mul_objs_pattern" $mf)
        if [ "$match" != "" ]; then
            echo "check_conf $match"
            check_conf $mf $match
        else
            echo "No kernel option for $filname"
            exit 0
        fi
    fi
}

# find out dependency for one option
function check_denpendency()
{
    # read kconfig file
    local kconf_file=$2
    local kconf=$1
    local pattern="^config ${kconf:7}$"
    local dep_pattern="[!A-Z0-9_]+"
    local kconf_out=""
    local line_nu=""
    local new_conf=0

    echo "Checking $kconf_file for $kconf"

    if [[ -z $kconf_file ]]; then
        echo "$kconf_file is empty"
        return
    fi
    kconf_out=$(grep -n "$pattern" $kconf_file)
    if [[ $kconf_out == "" ]]; then
        new_conf=0
        echo "no matched line with $pattern"
        return $new_conf
    fi
    echo "check_denpendency $kconf_out"

    line_nu=$(echo $kconf_out | awk -F ':' '{print $1}')

    # read kconfig section
    while IFS= read -r line; do
        if [[ $line =~ "depends on" ]]; then
            # find out multiple matches in one line
            while [[ $line =~ $dep_pattern ]]; do
                echo "new denpendency ${BASH_REMATCH[0]} for $kconf"
                if [[ ${BASH_REMATCH[0]:0:1} == "!" ]]; then
                    add_kconf_unset "${BASH_REMATCH[0]}"
                    line=${line/"${BASH_REMATCH[0]}"/}
                    continue
                fi
                add_kconf "${BASH_REMATCH[0]}"
                new_conf=$((new_conf+1))
                line=${line/"${BASH_REMATCH[0]}"/}
            done
        fi
        if [[ $line =~ ^[[:space:]]help$ ]] || [[ $line =~ ^$ ]]; then
            echo "no more depends"
            break
        fi
    done < <(tail -n "+$line_nu" $kconf_file)

    return $new_conf
}

# check out all dependency recursively
function bfs()
{
    local kconf_file=""
    local new_conf=0
    local need_recall=0

    printf "\ndoing search for:\n"
    for kconf in ${kconf_queue[@]}; do
        echo "+++ grab $kconf for kconf_queue +++"
        kconf_queue=(${kconf_queue[@]/$kconf})
        kconf_visited+=("CONFIG_$kconf")
        echo $(pwd)
        next_den=$(grep -Irns "^config $kconf$")
        if [[ -n $next_den ]]; then
           while IFS= read -r line; do
               kconf_file=$(awk -F ":" '{print $1}' <<< $line)
               echo "search next config: $kconf, $kconf_file"
               check_denpendency "CONFIG_$kconf" "$kconf_file"
               new_conf=$?
               if [[ $new_conf -gt 0 ]] || [[ $need_recall -eq 0 ]]; then
                   need_recall=$new_conf
               fi
           done <<< $next_den
        fi
    done

    if [[ $need_recall -gt 0 ]]; then
        echo "bfs second iteration"
        for conf in ${kconf_queue[@]}; do
            echo "$conf"
        done
        bfs
    fi
}

function print_kconf_list()
{
    if [[ ${#kconf_queue[@]} -ne 0  ]]; then
        printf "\ncheck the kconf_queue:\n"
        for conf in ${kconf_queue[@]}; do
            echo "$conf"
        done
    fi
    printf "\nThe denpendency of options of $rel_file are:\n"
    for conf in ${kconf_visited[@]}; do
        echo "$conf"
    done

    if [[ ${#kconf_unset[@]} -ne 0  ]]; then
        printf "\nyou should unset the kconf below:\n"
        for conf in ${kconf_unset[@]}; do
            echo "$conf"
        done
    fi
}

function main()
{
    parse_args "$@"

    if [[ "$file" == "" ]] || [[ ! -f $file ]]; then
        echo "The source file is not correct"
        usage
        exit 1
    fi

    if [[ ! -d "$source" ]] || [[ ! -f "$source/Kconfig" ]]; then
        echo "The kernel source tree is not correct"
        usage
        exit 1
    fi

    cd $source
    # prepare to search
    get_relative_path $source $file
    get_kconf_files $rel_file
    check_conf $makefile $filename
    # start doing search
    bfs

    # print result
    print_kconf_list
}

main "$@"
