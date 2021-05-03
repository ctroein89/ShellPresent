#!/bin/bash

SAVEIFS="$IFS"
IFS="-"

while getopts "f:" opt; do
	case ${opt} in
		f)
			oldIFS="$IFS"
			while IFS= read -r p; do
				rawSlides="$rawSlides\n$p"
			done < "$OPTARG"
			IFS="$oldIFS"
		;;
		\? )

		#print option error
		echo "Invalid option: $OPTARG" 1>&2
		;;
		: )

		#print argument error
		echo "Invalid option: $OPTARG requires an argument" 1>&2
		;;
	esac
done

printf '<%s>\n' "$rawSlides"
cleanedRawSlides=$(awk '{ gsub(/---/,"🔨"); print; }' <<<"$rawSlides")
printf '<%s>\n' "$cleanedRawSlides"
oldIFS="$IFS"
IFS="🔨"
read -ra slides <<<"$cleanedRawSlides"
IFS="$oldIFS"
printf '<%s>\n' "$slides"

printLine() {
	line="$@"
	# slide=$(sed "s/# /\\033[1m# /" <<<"$slide")
	if grep -q -E "^# " <<<"$line"; then
		line="\033[1m$line\033[0m"
	fi
	codeBlockChar=$(printf \\$(printf '%03o' 96))
	test=$codeBlockChar$codeBlockChar$codeBlockChar
	if grep -q -E $test <<<"$line"
	then
		if [[ $inCodeBlock == 1 ]]
		then
			inCodeBlock=0
			line="$line\033[0;37m"
		else
			inCodeBlock=1
			line="\033[1;34m$line"
		fi
	fi
	printf %b "$line\n"
}

printSlide() {
	input="$@"
	input=$(awk '{ gsub(/\\n/,"🔨"); print; }' <<<"$input")
	oldIFS="$IFS"
	IFS="🔨" read -ra slide <<<"$input"
	IFS="$oldIFS"
	# printf "\n<<%s>>" "$slide"
	for line in "${slide[@]}"; do
		printLine "$line"
		line=""
	done
	slide=""
	# read
}

# IFS="\n" read slides <<< "$slides"
for (( i=0; i<${#slides[@]}; i++ ))
do
	clear
	printSlide "${slides[$i]}"
	read -rsn1 keypress
	case $keypress in
		"<")
			# Go back 2 so that next instance of loop will be back one
			i=$(expr $i - 2)
			;;
		">" | " " | "")
			# Do nothing and slide will advance
			;;
		*)
			i=$(expr $i - 1)
			;;

	esac
	keypress=""
done
