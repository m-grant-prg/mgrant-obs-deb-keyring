#! /usr/bin/env bash

#########################################################################
#									#
# Script ID: gen-keyring.sh						#
# Author: Copyright (C) 2022, 2023  Mark Grant				#
#									#
# Released under the GPLv3 only.					#
# SPDX-License-Identifier: GPL-3.0-only					#
#									#
# Purpose:								#
# This script retrieves the openSUSE Build Service signing keys for	#
# Debian and Raspbian. It then generates a keyring.			#
#									#
# Syntax:	gen-keyring.sh						#
#									#
# Exit codes used:-							#
# Bash standard Exit Codes:	0 - success				#
#				1 - general failure			#
# User-defined exit code range is 64 - 113				#
#	C/C++ Semi-standard exit codes from sysexits.h range is 64 - 78	#
#		EX_USAGE	64	command line usage error	#
#		EX_DATAERR	65	data format error		#
#		EX_NOINPUT	66	cannot open input		#
#		EX_NOUSER	67	addressee unknown		#
#		EX_NOHOST	68	host name unknown		#
#		EX_UNAVAILABLE	69	service unavailable		#
#		EX_SOFTWARE	70	internal software error		#
#		EX_OSERR	71	system error (e.g., can't fork)	#
#		EX_OSFILE	72	critical OS file missing	#
#		EX_CANTCREAT	73	can't create (user) output file	#
#		EX_IOERR	74	input/output error		#
#		EX_TEMPFAIL	75	temp failure; user is invited	#
#					to retry			#
#		EX_PROTOCOL	76	remote error in protocol	#
#		EX_NOPERM	77	permission denied		#
#		EX_CONFIG	78	configuration error		#
#	User-defined (here) exit codes range 79 - 113:			#
#		None							#
#									#
# Further Info:								#
# OBS keeps a key per repository so they could be different although at	#
# the moment they are all the same. We should not assume this to be the	#
# case though. So, we cannot iterate over the repositories in the OBS	#
# recommended way							#
#	curl								#
#		gpg --dearmor						#
#			tee 						#
#				as that would overwrite the file each	#
# time. Equally we cannot do the same sequence with tee --append as in	#
# the current sceanrio we would get 3 copies of the same key.		#
# We cannot use apt-key add as apt-key is deprecated.			#
# So the preferred method is for each repository			#
#	curl								#
#		gpg --import --no-default-keyring --keyring X		#
# then after all repos processed					#
#	gpg --export --no-default-keyring --keyring X			#
#									#
#########################################################################

#########################################################################
#									#
# Changelog								#
#									#
# Date		Author	Version	Description				#
#									#
# 14/01/2022	MG	1.0.1	Created.				#
# 06/01/2023	MG	1.0.2	Remove no longer available Raspbian 9.0	#
#				Replace keyring only if it has changed.	#
# 29/03/2023	MG	1.0.3	Add Debian_Testing repo.		#
#									#
#########################################################################


##################
# Init variables #
##################

readonly version=1.0.3			# set version variable

basedir=$(dirname "$0")

distro_repos="Debian_Testing Debian_11 Debian_10 Debian_9.0 Raspbian_11"
distro_repos+=" Raspbian_10"


#############
# Functions #
#############

# Standard function to emit messages depending on various parameters.
# Parameters -	$1 What:-	The message to emit.
#		$2 Where:-	stdout == 0
#				stderr == 1
# No return value.
output()
{
	if (( !$2 )); then
		printf "%s\n" "$1"
	else
		printf "%s\n" "$1" 1>&2
	fi
}

# Standard function to tidy up and return exit code.
# Parameters - 	$1 is the exit code.
# No return value.
script_exit()
{
	exit $1
}

# Standard function to test command error and exit if non-zero.
# Parameters - 	$1 is the exit code, (normally $? from the preceding command).
# No return value.
std_cmd_err_handler()
{
	if (( $1 )); then
		script_exit $1
	fi
}

# Standard trap exit function.
# No parameters.
# No return value.
trap_exit()
{
	local -i exit_code=$?
	local msg

	msg="Script terminating with exit code $exit_code due to trap received."
	output "$msg" 1
	script_exit $exit_code
}

# Setup trap
trap trap_exit SIGHUP SIGINT SIGQUIT SIGTERM


########
# Main #
########

for repo in $distro_repos; do
	curl -fsSL"$verbose" \
		https://download.opensuse.org/repositories/home:m-grant-prg/$repo/Release.key \
		| gpg --import --no-default-keyring \
			--keyring $basedir/src/conf/etc/gpg.tmp
	std_cmd_err_handler $?
done

gpg --export --no-default-keyring --keyring $basedir/src/conf/etc/gpg.tmp \
	--output $basedir/src/conf/etc/home_m-grant-prg.gpg.new
std_cmd_err_handler $?

if cmp -s "$basedir/src/conf/etc/home_m-grant-prg.gpg" \
	"$basedir/src/conf/etc/home_m-grant-prg.gpg.new"; then
	std_cmd_err_handler $?
	rm $basedir/src/conf/etc/home_m-grant-prg.gpg.new
	std_cmd_err_handler $?
	printf "No changes. Old keyring kept.\n"
else
	rm $basedir/src/conf/etc/home_m-grant-prg.gpg
	mv $basedir/src/conf/etc/home_m-grant-prg.gpg.new \
		$basedir/src/conf/etc/home_m-grant-prg.gpg
	printf "Changes made, keyring replaced.\n"
fi

rm $basedir/src/conf/etc/*.tmp
std_cmd_err_handler $?

script_exit 0

