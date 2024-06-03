#!/bin/bash

declare -A exit_info
exit_info["0"]="Searching Done"
exit_info["10"]="main(): The source file is not correct"
exit_info["11"]="main(): The kernel source tree is not correct"
exit_info["20"]="get_relative_path(): The relative path doesn't exist"
exit_info["30"]="get_kconf_files(): The related Makefile and Kconfig don't exist"
exit_info["40"]="check_conf(): No kernel option for the related object"
exit_info["41"]="check_conf(): searching ERROR for the related object"

./ckd.sh -f /nobackup/xsong2/workspace/linux/drivers/gpu/drm/i915/i915_gem_evict.c -s /nobackup/xsong2/workspace/linux
./ckd.sh -f /nobackup/xsong2/workspace/linux/drivers/gpu/drm/i915/i915_hwmon.c -s /nobackup/xsong2/workspace/linux
./ckd.sh -f /nobackup/xsong2/workspace/linux/drivers/edac/zynqmp_edac.c -s /nobackup/xsong2/workspace/linux
./ckd.sh -f /nobackup/xsong2/workspace/linux/drivers/usb/core/port.c -s /nobackup/xsong2/workspace/linux
