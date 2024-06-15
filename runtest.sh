#!/bin/bash

declare -A exit_info
exit_info["0"]="Searching Done"
exit_info["1"]="main(): The source file is not correct"
exit_info["2"]="main(): The kernel source tree is not correct"
exit_info["10"]="get_relative_path(): The relative path doesn't exist"
exit_info["20"]="get_kconf_files(): The related Makefile and Kconfig don't exist"
exit_info["30"]="check_conf(): No kernel option for the related object"
exit_info["31"]="check_conf(): searching ERROR for the related object"

declare -A test_cases
test_cases[0]="drivers/gpu/drm/i915/i915_gem_evict.c"
test_cases[1]="drivers/gpu/drm/i915/i915_hwmon.c"
test_cases[2]="drivers/edac/zynqmp_edac.c"
test_cases[3]="drivers/usb/core/port.c"
test_cases[4]="kernel/relay.c"

source_tree=$1

function check_env()
{
    local st=$1

    if [[ ! -d "$st" ]] || [[ ! -f "$st/Kconfig" ]]; then
        echo "The kernel source tree is not correct"
        exit 1
    fi
}

function runtest()
{
    local source_abs=""
    local exit_code=0
    local st=$1

    for source_file in "${test_cases[@]}"; do
        source_abs="$st/$source_file"
        echo "Checking $st/$source_file"
        ./ckd.sh -f $source_abs -s $st
        exit_code=$?
        if [[ $exit_code -gt 0 ]]; then
            echo "FAILED: ${exit_info["$exit_code"]} : $source_file"
        else
            echo "PASSED: $source_file"
        fi
    done
}

check_env "$source_tree"
runtest "$source_tree"
