#!/bin/sh

OTP_STATE_DIR=~/.otp_state
DEBUG=		# set to anything to enable debug messages
DELAY_TIME=2	# time to sleep to slow OTP guessing attempts

do_die () {
    if [ "$2" -a "$DEBUG" ]
    then
        echo "$2"
    fi

    if [ "$1" ]
    then
        exit $1
    else
        exit 1
    fi
}

if [ $# -ne 1 ]
then
    do_die 1 "Invalid number of args: $#."
fi

secret=$(cat 2>/dev/null "$OTP_STATE_DIR/secrets/$1")
if [ -z "$secret" ]
then
    do_die 1 "Invalid secret specified: $1."
fi

if [ -z "$OTP_CODE" ]
then
    do_die 1 "No OTP_CODE passed via environment."
fi

if [ -z "$SSH_ORIGINAL_COMMAND" ]
then
    SSH_ORIGINAL_COMMAND="$(getent passwd $(whoami) | cut -d":" -f7) -l"
fi

# Time delay to limit guessing attempts
sleep $DELAY_TIME

# Validate provided OTP_CODE for current time period
oathtool --totp -b "$secret" "$OTP_CODE" > /dev/null 2>&1
cur_valid=$?

# Validate provided OTP_CODE for one previous time period
oathtool -N "-30seconds" --totp -b "$secret" "$OTP_CODE" > /dev/null 2>&1
old_valid=$?

# Get current counter value to set state
counter=$(( $(date "+%s") / 30 ))

if [ $cur_valid -eq 0 -o $old_valid -eq 0 ]
then
    # Calculate adjustment to counter based on if we see the previous code
    if [ $old_valid -eq 0 ]
    then
        adj=1
    else
        adj=0
    fi

    if [ -w "$OTP_STATE_DIR/counters/$1" ]
    then
        stored=$(cat 2>/dev/null "$OTP_STATE_DIR/counters/$1")
        if [ -n "${stored##*[! 0-9]*}" ]
        then
            if [ $stored -lt $(( $counter - $adj )) ]
            then
                echo 2>/dev/null "$counter" > "$OTP_STATE_DIR/counters/$1" 2>/dev/null
                if [ $? -eq 0 ]
                then
                    unset OTP_CODE
                    exec $SSH_ORIGINAL_COMMAND
                else
                    do_die 1 "Couldn't write new counter to state file."
                fi
            else
                do_die 1 "Stored counter is too recent."
            fi
        else
            do_die 1 "Stored counter is not a number."
        fi
    else
        do_die 1 "Counter file does not exist or is not writeable."
    fi
else
    do_die 1 "Supplied code is not valid."
fi
