#!/bin/bash

THRESHOLD_FILE="fan_thresholds.txt"
LOG_FILE="/var/log/gpu_fan_control.log"


# Liczba GPU
GPU_COUNT=$(nvidia-smi -L | grep -c "^GPU ")
echo "Licza GPU: $GPU_COUNT"

if [[ "$GPU_COUNT" -eq 0 ]]; then
    echo "Brak wykrytych kart graficznych NVIDIA. Koñczê."
    exit 1
fi

declare -gA FAN_TO_GPU
declare -A FAN_BASE_SPEED
declare -A USED_FAN

FAN_IDS=$(nvidia-settings -q fans -t | grep -oP 'fan:\K[0-9]+')
echo "Rozpoczynam mapowanie wentylatorów do GPU..."

# W³¹cz rêczne sterowanie dla wszystkich GPU
for ((i=0; i<GPU_COUNT; i++)); do
	sudo nvidia-settings -a "[gpu:$i]/GPUFanControlState=1" > /dev/null
done

# Ustaw wszystkie wentylatory na 100%
for FAN in $FAN_IDS; do
	sudo nvidia-settings -a "[fan:$FAN]/GPUTargetFanSpeed=100" > /dev/null
done

sleep 2  # daj czas na reakcjê

# Zapamiêtaj wartoœci bazowe
for FAN in $FAN_IDS; do
	SPEED=$(nvidia-settings -q "[fan:$FAN]/GPUTargetFanSpeed" | grep 'Attribute' | grep -o '[0-9]\+' | tail -n1)
	FAN_BASE_SPEED[$FAN]=$SPEED
done

echo $FAN_BASE_SPEED

# Iteruj po GPU i obserwuj spadki
for ((i=0; i<GPU_COUNT; i++)); do
	echo "Testujê GPU $i"
	sudo nvidia-settings -a "[gpu:$i]/GPUFanControlState=0" > /dev/null
	sleep 2

	for FAN in $FAN_IDS; do
		[[ ${USED_FAN[$FAN]} ]] && continue  # pomiñ ju¿ przypisane

		NEW_SPEED=$(nvidia-settings -q "[fan:$FAN]/GPUTargetFanSpeed" | grep 'Attribute' | grep -o '[0-9]\+' | tail -n1)

		if [[ "$NEW_SPEED" -lt "${FAN_BASE_SPEED[$FAN]}" ]]; then
			echo "Fan $FAN › GPU $i (spad³o z ${FAN_BASE_SPEED[$FAN]}% na $NEW_SPEED%)"
			FAN_TO_GPU[$FAN]=$i
			USED_FAN[$FAN]=1
		fi
	done

	# Przywróæ rêczny tryb (opcjonalnie)
	sudo nvidia-settings -a "[gpu:$i]/GPUFanControlState=1" > /dev/null
done

echo $FAN_TO_GPU
echo "Mapowanie zakoñczone. Wynik:"
for FAN in "${!FAN_TO_GPU[@]}"; do
	echo "Fan $FAN -> GPU ${FAN_TO_GPU[$FAN]}"
done



# Wczytanie progów temperatury
declare -A FAN_MAP
#while read -r TEMP FAN; do
    #[[ -z "$TEMP" || -z "$FAN" ]] && continue
    #FAN_MAP[$TEMP]=$FAN
#done < "$THRESHOLD_FILE"

#while IFS=' ' read -r TEMP FAN || [[ -n "$TEMP" ]]; do
#    [[ -z "$TEMP" || -z "$FAN" ]] && continue
#    FAN_MAP[$TEMP]=$FAN
#done < "$THRESHOLD_FILE"

FAN_MAP[35]=20
FAN_MAP[36]=22
FAN_MAP[37]=24
FAN_MAP[38]=26
FAN_MAP[39]=28
FAN_MAP[40]=30
FAN_MAP[41]=32
FAN_MAP[42]=34
FAN_MAP[43]=36
FAN_MAP[44]=38
FAN_MAP[45]=40
FAN_MAP[46]=42
FAN_MAP[47]=44
FAN_MAP[48]=46
FAN_MAP[49]=48
FAN_MAP[50]=50
FAN_MAP[51]=52
FAN_MAP[52]=54
FAN_MAP[53]=56
FAN_MAP[54]=58
FAN_MAP[55]=60
FAN_MAP[56]=62
FAN_MAP[57]=64
FAN_MAP[58]=66
FAN_MAP[59]=68
FAN_MAP[60]=70
FAN_MAP[61]=72
FAN_MAP[62]=74
FAN_MAP[63]=76
FAN_MAP[64]=78
FAN_MAP[65]=80
FAN_MAP[66]=82
FAN_MAP[67]=84
FAN_MAP[68]=86
FAN_MAP[69]=88
FAN_MAP[70]=90
FAN_MAP[71]=92
FAN_MAP[72]=94
FAN_MAP[73]=96
FAN_MAP[74]=98
FAN_MAP[75]=100

# Posortowane progi (rosn¹co)
#TEMPS=( $(printf '%s\n' "${!FAN_MAP[@]}" | sort -n) )
TEMPS=( $(for k in "${!FAN_MAP[@]}"; do echo "$k"; done | sort -n) )
echo "TEMPS: ${TEMPS[@]}"

while true; do 
	for ((i=0; i<GPU_COUNT; i++)); do
		STATE=$(nvidia-settings -q "[gpu:$i]/GPUFanControlState" | grep 'Attribute' | grep -o '[0-9]\+' | tail -n1)	
		if [[ "$STATE" -ne 1 ]]; then
			sudo nvidia-settings -a "[gpu:$i]/GPUFanControlState=1"
		fi
		
		# Aktualna temperatura GPU
		TEMP=$(nvidia-smi -i "$i" --query-gpu=temperature.gpu --format=csv,noheader,nounits)

		# Maksymalna temperatura (shutdown)
		MAX_TEMP=$(nvidia-smi -q -i "$i" | awk -F': ' '/GPU Shutdown Temp/ {print $2}' | awk '{print $1}')
		if [[ -z "$MAX_TEMP" ]]; then
			MAX_TEMP="---"
			#echo "GPU $i: TEMP='$TEMP'"
			#echo "Nie uda³o siê odczytaæ temperatury krytycznej GPU $i – pomijam."
			#continue
		fi
		
		#TEMP=100 
		echo "GPU $i: TEMP='$TEMP' |(max: $MAX_TEMP)"

		# Domyœlnie ustaw najni¿sz¹ prêdkoœæ z progów
		FAN_SPEED=${FAN_MAP[${TEMPS[0]}]}

		# Dobierz prêdkoœæ wentylatora na podstawie temperatury
		for T in "${TEMPS[@]}"; do
			if (( TEMP >= T )); then
				FAN_SPEED=${FAN_MAP[$T]}
			fi
		done

		# W³¹cz rêczne sterowanie wentylatorami
		#nvidia-settings -a "[gpu:$i]/GPUFanControlState=1" > /dev/null 2>&1
		
		#cho "FAN_SPEED $FAN_SPEED"

		for FAN in "${!FAN_TO_GPU[@]}"; do
			if [[ "${FAN_TO_GPU[$FAN]}" -eq "$i" ]]; then
				echo "fan:$FAN (GPU $i) -> $FAN_SPEED%"
				sudo nvidia-settings -a "[fan:$FAN]/GPUTargetFanSpeed=$FAN_SPEED" > /dev/null
			fi
		done

		# Logowanie przekroczenia temperatury krytycznej
		#if (( TEMP >= MAX_TEMP )); then
			#echo "$(date): GPU $i – TEMP ${TEMP}°C przekracza MAX ${MAX_TEMP}°C (FAN ${FAN_SPEED}%)" # >> "$LOG_FILE"
		#fi
	done
	
	sleep 2
done

# W³¹cz rêczne sterowanie dla wszystkich GPU
for ((i=0; i<GPU_COUNT; i++)); do
	sudo nvidia-settings -a "[gpu:$i]/GPUFanControlState=1" > /dev/null
done

# Ustaw wszystkie wentylatory na 95%
for FAN in $FAN_IDS; do
	sudo nvidia-settings -a "[fan:$FAN]/GPUTargetFanSpeed=95" > /dev/null
done
