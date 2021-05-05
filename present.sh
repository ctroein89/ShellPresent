#!/bin/bash

SAVEIFS="$IFS"
IFS="-"

while getopts "f:" opt; do
	case ${opt} in
		f)
			oldIFS="$IFS"
			filename="$OPTARG"
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
	clear
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
	height=$(tput lines)
	slideHeight=${#slide[@]}
	missingHeight=$(( $height - $slideHeight ))
	for (( j=1; j<$missingHeight; j++ )); do
		printf "\n"
	done
	printf "%s" " | $i / $max $filename | $(tput cols) x $(tput lines) | q : quit | → ↓ : next | ← ↑ : prev |"
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
	keypress=""
	mode=""
done
