#!/bin/bash

printHelp() {
	printf "%s" "Usage: present.sh [-h] [filename]"
	printf "%s" "    Presents a markdown-esque file as a slideshow"
	exit 1
}

while getopts "h" opt; do
	case ${opt} in
		h)
			printHelp
		;;
		\?)
		#print option error
		echo "Invalid option: $OPTARG" 1>&2
		;;
	esac
done

filename=${@:$OPTIND:1}
if [ "$filename" == "" ]
then
	echo "[filename] argument cannot be empty."
	exit 1
fi

oldIFS="$IFS"
while IFS= read -r p; do
	rawSlides="$rawSlides\n$p"
done < "$filename"
IFS="$oldIFS"

cleanedRawSlides=$(awk '{ gsub(/---/,"🔨"); print; }' <<<"$rawSlides")
oldIFS="$IFS"
IFS="🔨" read -ra slides <<<"$cleanedRawSlides"
IFS="$oldIFS"

fillBlankSpace() {
	lineCount=$1
	height=$(tput lines)
	missingHeight=$(( $height - $lineCount ))
	for (( j=0; j<$missingHeight; j++ )); do
		printf "\n"
	done
	printf "%b" "\e[0;37m | $i / $max $filename | $(tput cols) x $(tput lines) | q : quit | → ↓ : next | ← ↑ : prev |"
}

codeBlockChar=$(printf \\$(printf '%03o' 96))
codeBlockLine="$codeBlockChar$codeBlockChar$codeBlockChar"

printSlide() {
	# clear
	input="$@"
	input=$(awk '{ gsub(/\\n/,"🔨"); print; }' <<<"$input")
	oldIFS="$IFS"
	IFS="🔨" read -ra slide <<<"$input"
	IFS="$oldIFS"

	# Global state for slide
	output="\e[m"
	lineCount=0
	inCodeBlock="0"

	for line in "${slide[@]}"; do
		lineCount=$(( $lineCount + 1 ))

		# Line parsing somehow got a little weird with maintaing slide-state when
		# parsing lines was a seperate function, so it's all jammed in here

		foundHeaderHashtag="$(grep -q -E "^# " <<<"$line"; echo "$?")"
		foundCodeBlockBoundary="$(grep -q "$codeBlockLine" <<<"$line"; echo "$?")"
		if [ "$foundCodeBlockBoundary" == "0" ]
		then
			if [ $inCodeBlock == "0" ]
			then
				echo "blue"
				inCodeBlock="1"
			else
				echo "white"
				inCodeBlock="0"
			fi
		fi

		parsed="$line" # default state

		if [ "$foundHeaderHashtag" == "0" ]
		then
			parsed="\e[1m$line\e[m"
		fi

		if [ $inCodeBlock == "1" ]
		then
			parsed="\e[34m$line"
		else
			if [ "$foundCodeBlockBoundary" == "0" ]
			then
				parsed="$line\e[m"
			fi
		fi

		output="$output$parsed\n"
	done

	output="$output$(fillBlankSpace $lineCount)"

	# this print should output to screen
	printf %b "$output"
}

shouldContinue=1
i=0
max=${#slides[@]}
printSlide "${slides[$i]}"
while [ $shouldContinue == 1 ]
do
	escape_char=$(printf "\e")
	read -rsn1 mode # get 1 character
	if [[ $mode == $escape_char ]]; then
		read -rsn2 mode2 # read 2 more chars
		mode="$mode$mode2"
	fi
	keypress="${mode//$'\e'/}"
	case $keypress in
		"<"|$'[A'|$'0A'|$'[D'|$'0D')
			if [ $i -gt 0 ]; then
				i=$(( $i - 1 ))
				printSlide "${slides[$i]}"
			fi
			;;
		">"|" "|""|$'[B'|$'0B'|$'[C'|$'0C')
			if [ $i -lt $max ]
			then
				i=$(( $i + 1 ))
				printSlide "${slides[$i]}"
			fi
			;;
		q)
			shouldContinue=0
			;;
		*)
			;;
	esac

	# paranoid that these will hold over to next loop iteration
	keypress=""
	mode=""
done
