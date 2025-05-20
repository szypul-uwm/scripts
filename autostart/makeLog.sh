#!  /bin/bash

#*/1 * * * * /home/wamasoft/makeLog.sh  >> /home/wamasoft/makeLog.log

declare -i number
declare -i minBuffer
declare -i minTemp


serwer="platan4"
minTemp=$((60))
minBuffer=$((0))

while true; do
	# ------------------------------------------- GPU TEMPERATURE > 80----------------------------------------
	result=$(nvidia-smi -q -d temperature |grep "GPU Current Temp")
	arr=(${result//:})

	GPU0=${arr[3]}
	GPU1=${arr[8]}

	ddate=$((0))
	toSend=$((0))

	curl=""

	pusty=""
	gpu=""

	if ((arr[3] > minTemp)); then
		date
		echo "GPU 0: $GPU0"

		gpu="0-$GPU0"

		ddate=$((1))
		toSend=$((1))
	fi

	if ((arr[8] > minTemp)); then
		if ((ddate < 1)); then
			date
			gpu="1-$GPU1"
		else
			gpu="$gpu,1-$GPU1"
		fi

		echo "GPU 1: $GPU1"

		ddate=$((1))
		toSend=$((1))
	fi

	if ((gpu!=pusty)); then
		curl="$curl&gpu=$gpu"
	fi


	# ----------------------------- Buffor size > 5000 -----------------------------



	result=$(find /media/ramdisk -xdev -type f | cut -d "/" -f 4 | uniq -c)
	arr=(${result//:})

	len=${#arr[@]}

	buffer=""

	for (( i=0; i<$len; i++,i++))
	do
		number=${arr[i]}

		if (( number > minBuffer )); then

			if ((ddate < 1)); then
				date
			fi

			echo "${arr[i]}  F: ${arr[i + 1]}"
			ddate=$((1))
			toSend=$((1))

			buffer="$buffer,${arr[i + 1]}-${arr[i]}"
		fi;
	done

	buffer=$(echo $buffer|cut -c 2-)

	if ((buffer!=pusty)); then
		curl="$curl&buffer=$buffer"
	fi 


	# -------------------------------------------------- Last modification ------------------------------------------

	get_date() {
		date --utc --date="$1" +"%Y-%m-%d %H:%M:%S"
	}

	dateNow=$(date +"%FT%T")
	dateNow=$(get_date $dateNow)

	offline=""

	ramdiskLen=$(ls /media/ramdisk |wc -l)
	if ((ramdiskLen < 1)); then
		offline="&All"

	else

		for dir in /media/ramdisk/*
		do
			tmp="$(date -r $dir +"%F %T")";

			dateOfDir=$(date -d "$tmp 10 minutes" +"%FT%T")
			dateOfDir=$(get_date $dateOfDir)

			if [[ "$dateNow" > "$dateOfDir" ]]; then
				#echo "$dateNow > $dateOfDir"
				offline="$offline,$(basename $dir)"
				toSend=$((1))
			fi
		done
	fi

	offline=$(echo $offline|cut -c 2-)

	if ((${#offline} > 0)); then
		curl="$curl&offline=$offline"
		toSend=$((1))
	fi 


	
	cpuTemp=$(sensors | grep "Core")

	tempAll=""

	while read -r line; do
		core=$(echo "$line" | awk -F: '{print $1}' | grep -o '[0-9]\+')
		temp=$(echo "$line" | awk '{print $3}' | tr -d '+°C')
		
		tempAll="$tempAll,$core-$temp"
	done <<< "$cpuTemp"

	# Usunięcie pierwszego przecinka
	tempAll=${tempAll#,}

	if ((${#tempAll} > 0)); then
		curl="$curl&cpu=$tempAll"
		echo $tempAll
		toSend=$((1))
	fi 



	if ((toSend>0)); then
		curl1="http://status.blueye.cloud?server=$serwer$curl"
		curl2="http://pikora.wamasof2.vot.pl/data?server=$serwer$curl"

		#echo $curl
		wget --quiet --spider "$curl1"
		wget --quiet --spider "$curl2"
	fi
	sleep 30
done

