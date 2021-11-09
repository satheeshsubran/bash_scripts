#!/usr/bin/bash
#===============================================================================
#       FILE    : ss7_linkstatus.sh
#       USAGE   : ss7_linkstatus.sh
#
#   DESCRIPTION : DSI Card Link activation Status (Dialogic). The program
#                 helps to know the Dialogic SS7 cards link states utilizing
#                 the 'dsistat' command
#
#       OPTIONS : see function 'usage' below
#  REQUIREMENTS :
#       BUGS    : --
#       NOTES   : --
#       PLATFORM: Linux/Solaris
#       DSI     : All
#       AUTHOR  : Satheesh Subran
#       COMPANY : 
#       VERSION : 5.00
#       CREATED : 29-05-2012
#      REVISION : 12-04-2016
#                        - ISUP signaling is updated
#                 09-10-2016
#                        - Enhancement in sed
#                        - ISUP circuit status added
#                 25-10-2016
#                        - Advance,help option added
#                 09-05-2017
#                        - Enhanced to get the RSI link status
#                        - Bug fix for the multiple header
#                 27-08-2018
#                        - Enhanced RSI link status to use -dm parameter
#                 01-11-2018
#                        - For DSI V 5.5.x the RSIL status can be obtained by
#                          querying the remote RSI module id. Changes for this
#                          is added.
#                 06-11-2018
#                        - The alarm colouring is re-designed. Some bug fixes
#                          applied
#                 29-01-2020
#                        - The func. for colouring is modified
#                 25-02-2021
#                        - Enahnced the colouring with a function
#                 21-03-2021
#                        - Reset statistics feature added
#                 30-03-2021
#                        - Correction of IPADDR parameter in Association check
#===============================================================================
# set -x
 
# ----------- This needs to be changed accordingly --------
moduleid='-m0x3d'
 
err_no_awk_cmd=101
err_no_cfg=102
err_finish_isup=103
err_usage=104
err_no_sed_cmd=105
err_finish_tdm=106
 
[ "$(uname)" == "Linux" ] &&
{ _os='Linux' ; } ||
{ _os='SunOS' ; }
export _os
 
red='echo -e "\033[0;31m&\033[0;37m"'
green='echo -e "\033[0;32m&\033[0;37m"'
yellow='echo -e "\033[0;33m&\033[0;37m"'
 
#- DEFINITIONS -----------------------------
# Global Variables
# Note: Please configure correct moduleid of
# DSI statistcs from system.txt file.
#-------------------------------------------
 
_config_file=/septel/config.txt
_system_file=/septel/system.txt
_awk=$(which awk 2>/dev/null)
 
#= FUNCTION ===========================================================
# NAME          : showit
# DESCRIPTION   : Function displays the alarm text with coloring
# PARAMETER 1   : Expected alarm result
#======================================================================
showit () {
 
 
local alarm_text=${1:-'Unknown'}
 
/bin/sed -e \
'
/^[0-9,-]/ {
        /\<'${alarm_text}'\>/ {
                s/'${alarm_text}'/'$(eval ${green})'/g
        }
}
' -e t -e \
'
/^[0-9,-]/ {
        /\<'${alarm_text}'\>/ !{
                s/\<[A-Z,a-z].*\>/'$(eval ${red})'/g
        }
}
'
}
 
#= FUNCTION ===========================================================
# NAME          : heading
# DESCRIPTION   : Function displays heading of the section and line
# PARAMETER 1   : Expected alarm result
#======================================================================
heading() {
        h_statement=${1}
        h_line_pattern=${2}
        h_line_length=${3}
 
        printf "\t${h_statement}\n"
        printf "%${h_line_length}s\n" ${h_line_pattern} |
        sed 's/ /'${h_line_pattern}'/g'
}
 
################# DO NOT CHANGE BELOW THIS #############################
 
# - Command verification --------------------
#-------------------------------------------
 
if ! type  sed >/dev/null; then
        echo "No sed command found.";
        exit $err_no_sed_cmd ;
else
        _sed=$(which sed 2>/dev/null);
fi
if ! type awk >/dev/null; then
        echo "No awk command found.";
        exit $err_no_sed_cmd ;
else
        _awk=$(which awk 2>/dev/null);
fi
 
while getopts "a r h" arg
do
        case $arg in
                a|advance)
                        option=1
                        shift ;
                ;;
                r|reset)
                        option=2
                        shift ;
                ;;
                h|help)
                        echo -e "Usage : - \n\n $0 <options>\n"
                        echo -e "h -> help \na -> advance feature"
                        echo -e "r -> reset statistics\n"
                        exit $error_usage
                ;;
        esac
done
 
clear
 
# - TDM signalling status ------------------
# Below configuration is to check TDM
# signalling status.
#-------------------------------------------
if  [ -f $_config_file ] && [ "" != "$(grep LIU_CONFIG ${_config_file})" ]
then
        heading '
This is TDM signalling.
 
Config file found, parsing config file,checking  links status ...' '-' 65
        heading 'Physical LIU status' '-' 65
        $_awk '$1~/^LIU_CONFIG$/ \
                { print $3"\t""-di"$2"\t"mod" -sr"}' "mod=$moduleid" ${_config_file} |
                xargs -n 4 /opt/DSI/dsistat LIU STATUS $1 2>&1 |
                                sed -e '2,${/^BOARD.*$/d;}' |
                showit OK
        heading '' '-' 65
        echo -e "\tMTP SS7 links status"
        $_awk '$1~/^MTP_LINK$/ \
                { print $3"-"$4"\t"mod" -sr"}' "mod=$moduleid" ${_config_file} |
                xargs -n  3 /opt/DSI/dsistat MTPL STATUS $1 2>&1 |
                                sed -e '2,${/^LS  REF.*$/d;}' |
                showit AVAILABLE
        heading 'MTP3 Route status' '-' 65
        $_awk '$1~/^MTP_ROUTE$/ { print $2"\t"mod" -sr"}' "mod=$moduleid" ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat MTPR STATUS $1 2>&1 |
                                sed -e '2,${/^DPC.*$/d;}' |
                showit Available
        [ "x1" == "x$option" ] &&
        {
                heading 'Physical LIU statistics' '-' 65
                $_awk '$1~/^LIU_CONFIG$/ \
                        { print $3"\t""-di"$2"\t"mod" -sr"}' "mod=$moduleid" ${_config_file} |
                        xargs -n 4 /opt/DSI/dsistat LIU STATS $1 2>&1 |
                        sed -e '2,${/^BOARD.*$/d;}'
                heading 'MTP SS7 links status' '-' 65
                                $_awk '$1~/^MTP_LINK$/ \
                                                { print $3"-"$4"\t"mod" -sr"}' "mod=$moduleid" ${_config_file} |
                        xargs -n  3 /opt/DSI/dsistat MTPL STATS $1 2>&1 |
                        sed -e '2,${/^LS  REF.*$/d;}'
                                heading 'MTP3 Route status' '-' 65
                $_awk '$1~/^MTP_ROUTE$/ \
                                                { print $2"\t"mod" -sr"}' "mod=$moduleid" ${_config_file} |
                        xargs -n 3 /opt/DSI/dsistat MTPR STATS $1 2>&1 |
                        sed -e '2,${/^DPC.*$/d;}'
                echo
        }
                [ "x2" == "x$option" ] &&
        {
                heading 'Physical LIU statistics' '-' 65
                $_awk '$1~/^LIU_CONFIG$/ \
                        { print $3"\t""-di"$2"\t"mod" -sr -r"}' "mod=$moduleid" ${_config_file} |
                        xargs -n 5 /opt/DSI/dsistat LIU STATS $1 2>&1 |
                        sed -e '2,${/^BOARD.*$/d;}'
                heading 'MTP SS7 links status' '-' 65
                                $_awk '$1~/^MTP_LINK$/ \
                                                { print $3"-"$4"\t"mod" -sr -r"}' "mod=$moduleid" ${_config_file} |
                        xargs -n  4 /opt/DSI/dsistat MTPL STATS $1 2>&1 |
                        sed -e '2,${/^LS  REF.*$/d;}'
                                heading 'MTP3 Route status' '-' 65
                $_awk '$1~/^MTP_ROUTE$/ \
                                                { print $2"\t"mod" -sr -r"}' "mod=$moduleid" ${_config_file} |
                        xargs -n 4 /opt/DSI/dsistat MTPR STATS $1 2>&1 |
                        sed -e '2,${/^DPC.*$/d;}'
                echo
        }
        exit $err_finish_tdm;
 
# - ISUP signalling status -----------------
# Below configuration is to check ISUP
# over TDM/SIGRAN signalling status.
#-------------------------------------------
elif [ -f $_config_file ] && [ "" != "$(grep \"^ISUP_CONFIG\" ${_config_file})" ]
then
 
        heading '
This is SIGTRAN ISUP signalling.
 
Config file found, parsing config file,checking circuit status ...' '-' 65
        heading 'Signalling Association status' '-' 65
        $_awk 'BEGIN {FS=",";x=0} $1~/^SNSLI/ \
                { x=substr($1,14)-1;\
                print x" -sr "mod}' "mod=$moduleid" ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat SCTPA STATUS $1 2>&1 |
                showit ESTABLISHED
        [ "x1" == "x$option" ] &&
        {
                heading 'Signalling Association statistics' '-' 65
                $_awk 'BEGIN {FS=",";x=0} $1~/^SNSLI/ \
                        { x=substr($1,14)-1;\
                        print x" -sr "mod}' "mod=$moduleid" ${_config_file} |
                        xargs -n 3 /opt/DSI/dsistat SCTPA STATS $1 2>&1
        }
        heading 'M3UA Association status' '-' 65
        $_awk 'BEGIN {FS=",";x=0} $1 ~ /^SNSLI/ \
                { x=substr($1,14)-1;\
                print x" "mod" -sr"}' "mod=$moduleid"  ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat M3UAP STATUS $1 2>&1 |
                showit AVAILABLE
        heading 'M3UA Route status' '-' 65
        $_awk 'BEGIN {FS=",";x=0} $1~/^SNRTI/ \
                { x=substr($1,12)-1;\
                print x" "mod" -sr"}' "mod=$moduleid"  ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat M3UAR STATUS $1 2>&1 |
                showit AVAILABLE
        heading 'ISUP Circuit Group status' '-' 65
        $_awk '$1~/^ISUP_CFG_CCTGRP/ { print $2" "mod}' "mod=$moduleid" ${_config_file} |
                xargs -n 2  /opt/DSI/dsistat CGRP STATUS $1 2>&1 |
                sed     -e '/^Executed/d;
                                s/[0-9]./'$(echo -e "\033[31m&\033[37m")'/3;
                                s/[0-9]./'$(echo -e "\033[32m&\033[37m")'/7'
        [ "x1" == "x$option" ] &&
        {
                heading 'ISUP Circuit Group statistics' '-' 65
                $_awk '$1~/^ISUP_CFG_CCTGRP/ \
                        { print $2" "mod}' "mod=$moduleid" ${_config_file} |
                        xargs -n 2  /opt/DSI/dsistat CGRP STATS $1 2>&1 |
                        sed     -e '/^Executed/d;
                                        s/[0-9:]/&/g'
                heading 'ISUP Circuit status in each Group' '-' 65
                $_awk '$1~/^ISUP_CFG_CCTGRP/ \
                        { print $2" "mod}' "mod=$moduleid" ${_config_file} |
                        xargs -n 2  /opt/DSI/dsistat CCTS STATUS $1 2>&1 |
                        sed     -e '/^Executed/d;
                                        {/^CGRP/ !s/[A-Z_].* /'$(echo -e "\033[31m&\033[37m")'/1;}
                                        s/IDLE/'$(echo -e "\033[32m&\033[37m")'/g'
        }
        [ "x2" == "x$option" ] &&
        {
                heading 'ISUP Circuit Group statistics' '-' 65
                $_awk '$1~/^ISUP_CFG_CCTGRP/ { print $2" -r "mod}' "mod=$moduleid" ${_config_file} |
                        xargs -n 3  /opt/DSI/dsistat CGRP STATS $1 2>&1 |
                        sed     -e '/^Executed/d;
                                        s/[0-9:]/&/g'
                heading 'ISUP Circuit statistics in each Group' '-' 65
                $_awk '$1~/^ISUP_CFG_CCTGRP/ { print $2" -r "mod}' "mod=$moduleid" ${_config_file} |
                        xargs -n 3  /opt/DSI/dsistat CCTS STATS $1 2>&1 |
                        sed     -e '/^Executed/d;
                                        {/^CGRP/ !s/[A-Z_].* /'$(echo -e "\033[31m&\033[37m")'/1;}
                                        s/IDLE/'$(echo -e "\033[32m&\033[37m")'/g'
        }
        exit $err_finish_isup;
 
# - SIGTRAN signalling status ---------------
# Below configuration is to check SIGTRAN
# over SIGTRAN signalling status.
#-------------------------------------------
elif [ -f $_config_file ]
then
 
        heading '
This is SIGTRAN signalling.
 
Config file found,
parsing config file,checking  links status ...' '-' 65
        heading 'Signalling Association status' '-' 65
        $_awk 'BEGIN {FS=",";x=0} \
                $1~/^SNSLI/ { x=substr($1,14)-1;\
                print x" -sr "mod}' "mod=$moduleid" ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat SCTPA STATUS $1 2>&1 |
                sed -e '2,${/^SNLINK.*$/d;}'| sed -e 's/        / /g' |
                showit ESTABLISHED
        heading '' '-' 65
        $_awk 'BEGIN {
                FS=",";
                x=0;
                c=0;
                e=0;
        }
        {
                if ( $1 ~ /^SNSLI/ ) {
                for (i=1;i<=NF;i++) {
                        if ( $i ~ /^IPADDR/ ) {
                        c++;
                        }
                 }
                while ( c > 0 ) {
                        x=substr($1,14)-1;
                        print x"-"e" -sr " mod;
                        c--;e++;
                        }
                e=0;
                } else {
                # do nothing
                }
        }' "mod=$moduleid" ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat SCTPP STATUS $1 2>&1 |
                sed -e '2,${/^SNLINK.*$/d;}'| sed -e 's/        / /g' |
                showit ACTIVE
        echo -e
        heading 'M3UA Association status' '-' 65
        $_awk 'BEGIN {FS=",";x=0} \
                $1 ~ /^SNSLI/ { x=substr($1,14)-1;\
                print x" "mod" -sr"}' "mod=$moduleid"  ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat M3UAP STATUS $1 2>&1 |
                sed -e '2,${/^SNLINK.*$/d;}'|
                showit AVAILABLE
        echo -e
        heading 'M3UA Route status' '-' 65
        $_awk 'BEGIN {FS=",";x=0} \
        $1~/^SNRTI/ { x=substr($1,12)-1;\
        print x" "mod" -sr"}' "mod=$moduleid"  ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat M3UAR STATUS $1 2>&1 |
                sed -e '2,${/^SNRT.*$/d;}'| sed -e 's/        / /g' |
                showit AVAILABLE
        echo -e
        if [ "$(grep -c ^FORK_PROCESS.*rsicmd ${_system_file})" -gt 0 ]
        then
                heading 'RSI Link Status' '-' 65
                $_awk '/^FORK_PROCESS.*rsicmd/ \
                        { print $3" -sr"}' ${_system_file} |
                        xargs -n 2 /opt/DSI/dsistat RSIL STATUS $1 |
                        sed -e '2,${/^LINKID.*$/d;}'| sed -e 's/        / /g' |
                        showit ESTABLISHED
        fi
        echo -e
        heading 'Remote PC status' '-' 65
        $_awk '{ FS="," } /^SNRTI/ { gsub(/[^0-9]/,"",$2) ; \
                print $2" "mod" -sr"}' "mod=$moduleid"  ${_config_file} |
                xargs -n 3 /opt/DSI/dsistat RSP STATUS $1 2>&1 |
                sed -e '2,${/^[SPC,SSRID].*$/d;}'|
                showit ALLOWED
        echo -e
        [ "x1" == "x$option" ] &&
        {
                echo -e
                heading 'Signalling Association statistics' '-' 65
                $_awk 'BEGIN {FS=",";x=0} $1~/^SNSLI/ { x=substr($1,14)-1;\
                        print x" -sr "mod}' "mod=$moduleid" ${_config_file} |
                        xargs -n 3 /opt/DSI/dsistat SCTPA STATS $1 2>&1 |
                        sed -e '2,${/^SNLINK.*$/d;}'
                if [ "$(grep -c ^FORK_PROCESS.*rsicmd ${_system_file})" -gt 0 ]
                then
                        heading 'RSI link statistics' '-' 65
                        $_awk '/^FORK_PROCESS.*rsicmd/ { print $3" -sr" }' ${_system_file} |
                                xargs -n 2 /opt/DSI/dsistat RSIL STATS $1 2>&1 |
                                sed -e '2,${/^SNRT.*$/d;}'
                fi
                echo -e
        }
        [ "x2" == "x$option" ] &&
        {
                echo -e
                heading 'Signalling Association statistics' '-' 65
                $_awk 'BEGIN {FS=",";x=0} \
                        $1~/^SNSLI/ { x=substr($1,14)-1;\
                        print x" -sr -r "mod}' "mod=$moduleid" ${_config_file} |
                        xargs -n 4 /opt/DSI/dsistat SCTPA STATS $1 2>&1 |
                        sed -e '2,${/^SNLINK.*$/d;}'
                if [ "$(grep -c ^FORK_PROCESS.*rsicmd ${_system_file})" -gt 0 ]
                then
                        heading 'RSI link statistics' '-' 65
                        $_awk '/^FORK_PROCESS.*rsicmd/ { print $3" -sr -r" }' ${_system_file} |
                                xargs -n 3 /opt/DSI/dsistat RSIL STATS $1 2>&1 |
                                sed -e '2,${/^SNRT.*$/d;}'
                fi
                echo -e
        }
 
else
        echo -e "No config file found ..."
        exit $err_no_cfg;
fi
exit 0
