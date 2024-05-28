# check_kconfig_dependency
The tool is to help find out the dependency of a kernel option for a source file.

# Usage
ckd.sh OPTIONS \<path to source file\> OPTIONS \<path to source tree\>

example: ckd.sh -f path_to/abc.c -s path_to/linux

Options:
    -f, --file      the file you want to check for
    -s, --source    the kernel source
    -h, --help      print this help text and exit
