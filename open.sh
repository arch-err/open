#!/usr/bin/env bash
#!CMD: ./open.sh

# Author: arch-err
# Description: *open* is a cli tool that serves as an abstraction layer for opening files from the commandline.
#
#
# Dependencies:
#  - yq
#  - fzf
#  - file


SECONDARY=false
FZF_STANDARD_ARGS="--reverse --height 10"
MIME_TYPE_CMD='file --mime-type FILE'
# MIME_TYPE_CMD="magika -i FILE"


test -z $HOME || CONFIG_PATH="$HOME/.config/open/config.yaml"
test -z $XDG_CONFIG_HOME || CONFIG_PATH="$XDG_CONFIG_HOME/open/config.yaml"
CONFIG_PATH="./config.yaml"



if [ "$1" == "-s" ]
then
    shift 1
    SECONDARY=true
fi

FILES="$@"

if test -z "$FILES"
then
    FILES=$(fzf $FZF_STANDARD_ARGS --prompt "File to open: ")
fi



for FILE in $FILES
do
    MIME_TYPE_CMD=$(echo "$MIME_TYPE_CMD" | sed "s|FILE|$FILE|g")

    mime_type="$($MIME_TYPE_CMD | sed "s|$FILE: ||; s|\x1B\[[0-9;]*[JKmsu]||g")" # That weird-ass regex is a substitution to get rid of pesky colorcodes and such

    opener_type=$(yq ".openers[] | select(.mime_types[] == \"$mime_type\") | .type" $CONFIG_PATH)
    if $SECONDARY
    then
        openers=$(yq ".openers[] | select(.type == \"$opener_type\") | .tools.alt | join \", \"" $CONFIG_PATH)
        opener=$(echo $openers | sed 's/, /\n/g' | fzf $FZF_STANDARD_ARGS --prompt "Select opener command: ")
    else
        opener=$(yq ".openers[] | select(.type == \"$opener_type\") | .tools.main" $CONFIG_PATH)
    fi
    $opener $FILE
done
