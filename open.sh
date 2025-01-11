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
BASE_MIME_TYPE_CMD='file --mime-type FILE'
# BASE_MIME_TYPE_CMD="magika -i FILE"
test -z $HOME || CONFIG_PATH="$HOME/.config/open/config.yaml"
test -z $XDG_CONFIG_HOME || CONFIG_PATH="$XDG_CONFIG_HOME/open/config.yaml"
# CONFIG_PATH="./config.yaml"

set -e

# Arguments message
error() {
    local message="$1"
    printf "\e[0;31m$message\033[0m\n" >&2
}

# Arguments message
warn() {
    local message="$1"
    printf "\e[0;38;5;215m$message\033[0m\n" >&2
}

# Arguments message
success() {
    local message="$1"
    printf "\e[0;38;5;2m$message\033[0m\n"
}



new_type_str="Configure New Type"
new_opener_str="Configure New Opener"

ARGS=("$@")

if test -z "$ARGS"
then
    ARGS=$(fzf $FZF_STANDARD_ARGS --prompt "File to open: ")
fi


FILE_NUM=${#ARGS[@]}

# for FILE in FILES
for (( i=0; i < $FILE_NUM; i++)); do
    FILE=${ARGS[${i}]}

    if [ "$i" -gt "0" ]; then
        success "Working with file: '$FILE'"
    fi

    MIME_TYPE_CMD=$(echo "$BASE_MIME_TYPE_CMD" | sed "s|FILE|\"$FILE\"|g")

    mime_type="$(bash -c "$MIME_TYPE_CMD" | sed "s|$FILE: ||; s|\x1B\[[0-9;]*[JKmsu]||g")" # That weird-ass regex is a substitution to get rid of pesky colorcodes and such

    opener_type=$(yq ".openers[] | select(.mime_types[] == \"$mime_type\") | .type" $CONFIG_PATH)

    if test -z "$opener_type"; then
        warn "The file '$(basename "$FILE")' with mime-type '$mime_type' isn't configured to a certain command."
        type=$(yq ".openers[].type" $CONFIG_PATH | cat - <(echo "$new_type_str") | fzf --reverse --prompt "Which type of file is this? " --height 10)

        if [ "$type" == "$new_type_str" ]; then
            read -p "Type Name: " type
            if yq ".openers[].type" $CONFIG_PATH | grep -Pq "^$type$"; then
                error "The type '$type' is already configured!"
                error "Skipping this file..."
                continue
            fi

            yq -i ".openers += [{\"type\": \"$type\"}]" $CONFIG_PATH
        fi
        opener_type="$type"

        yq -i ".openers[] |= select(.type == \"$opener_type\") |= .mime_types += [\"$mime_type\"]" $CONFIG_PATH
    fi


    openers=$(yq ".openers[] | select(.type == \"$opener_type\") | .tools[].name" $CONFIG_PATH | sed "s/ /_/g")
    if test -z "$openers"; then
        warn "This file is configured to use a program of type '$opener_type' to open, but the type doesn't have any configured commands"
        read -p "Command Name: " opener_name
        read -e -i "$(echo $opener_name | tr '[:upper:]' '[:lower:]')" -p "Actual command: " opener_cmd
        yq -i ".openers[] |= select(.type == \"$opener_type\") .tools |= . + [{\"name\": \"$opener_name\", \"cmd\": \"$opener_cmd\"}]" $CONFIG_PATH
    else
        opener_name=$(echo $openers | sed 's/ \? /\n/g; s/_/ /g' | cat - <(echo "$new_opener_str") | fzf $FZF_STANDARD_ARGS --prompt "Select opener: ")

        if [ "$opener_name" == "$new_opener_str" ]; then
            read -p "Command Name: " opener_name
            read -e -i "$(echo $opener_name | tr '[:upper:]' '[:lower:]')" -p "Actual command: " opener_cmd
            yq -i ".openers[] |= select(.type == \"$opener_type\") .tools |= . + [{\"name\": \"$opener_name\", \"cmd\": \"$opener_cmd\"}]" $CONFIG_PATH
        else
            opener_cmd=$(yq ".openers[] | select(.type == \"$opener_type\") | .tools[] | select(.name == \"$opener_name\") | .cmd" $CONFIG_PATH)
        fi
    fi

    # test -z "${!opener_cmd}" || opener_cmd=${!opener_cmd}

    $opener_cmd "$FILE"
    sleep 0.1
done
