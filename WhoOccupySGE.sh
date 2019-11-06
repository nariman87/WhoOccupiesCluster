#!/bin/bash

### File name: WhoOccupySGE.sh 
### Author: Seyed Nariman Saadatmand 
### Contact: nariman.saadatmand@uq.edu.au  
ver="1.2.17"
### Kick-started in: 19/Sep/2016
### Descrption: using a customized "qstat" command to report how many CPU slots each user occupying on some
### specific queues.

# a function to check array element existence:
CheckArrayElement() {
  local passed_array=$2[@]
  passed_array=("${!passed_array}")
  local index
  for index in "${!passed_array[@]}"; do 
     if [[ "${passed_array[$index]}" == "$1" ]]; then
       echo $index
       return 1
     fi
  done
  return 0
}

NumberTest='^-?[0-9]+([.][0-9]+)?$'
declare -a user=()
declare -a name=()
declare -a user_slots=()
declare -a user_slots1=()
declare -a both_slots=()

mktemp 1> /dev/null; temp="$(mktemp)";

qstat -u '*' -g d > $temp
SplitLine=`awk '$5=="qw" {print NR; exit;}' $temp`
let SplitLine--
split --lines=${SplitLine} ${temp} ${temp}_
N=$(wc -l < "${temp}_aa")

i=0
j=0
while read -r line; do 

   let i++
   progress=`echo "scale=0; (${i}*100)/${N}" | bc -q`
   echo -en "\rworking %$progress"

   ID=`echo $line | awk '{print $1}'`

   q_name=`echo $line | awk '{print $8}'`
   q_name=${q_name%@*}

   state=`echo $line | awk '{print $5}'`

   #echo "DEBUG: for line=${i}, we have ID= \"${ID}\", state=\"${state}\", and q_name=\"${q_name}\" ..."

   if [[ ${ID} =~ ${NumberTest} ]] && [ "$state" == 'r' ] && [[ "$q_name" = *low* ]]; then

     user_test=`echo $line | awk '{print $4}'`
     index_test=`CheckArrayElement "$user_test" user`

     if [ -z $index_test ]; then              
       user[$j]=${user_test}
       name[$j]=`finger ${user[$j]} | awk 'NR==1 {print "\""$4, $5"\""}'`
       this_index=$j
       #echo "DEBUG: new user ${user_test} has been found, we set this_index=$j ..."
       let j++
     else
       this_index=$index_test
       #echo "DEBUG: user ${user_test} already exist, this_index=$index_test ..."
     fi

     slots=`echo $line | awk '{print $9}'`
 
     if [ "$q_name" == 'low.q' ]; then
       user_slots[$this_index]=$(( ${user_slots[$this_index]} + ${slots} ))
     elif [ "$q_name" == 'low1.q' ]; then
       user_slots1[$this_index]=$(( ${user_slots1[$this_index]} + ${slots} ))
     fi

     #echo "DEBUG: in line=${i}, we have user= \"${user[$this_index]}\", current_slots=${slots}, user_slots=${user_slots[$this_index]}, user_slots1=${user_slots1[$this_index]} ..."

   fi

done < ${temp}_aa

# printing final results in a desirley-formatted table:
mktemp 1> /dev/null; temp2="$(mktemp)";
echo -e "\n\nuser\tregistered_name\tlow.q_slots/TOTAL\tlow1.q_slots/TOTAL\tboth_slots/TOTAL"
echo "------------------------------------------------------------------------------------------------------------"

for k in "${!user[@]}"; do
   if [ -z ${user_slots[$k]} ]; then user_slots[$k]=0; fi
   if [ -z ${user_slots1[$k]} ]; then user_slots1[$k]=0; fi
   total=$(( ${user_slots[$k]} + ${user_slots1[$k]} ))
   printf "%10s\t%20s\t%i/576\t%i/220\t%i/796\n" "${user[$k]}" "${name[$k]}" ${user_slots[$k]} ${user_slots1[$k]} ${total} >> $temp2
done

sort -k6 -n -r $temp2

echo "------------------------------------------------------------------------------------------------------------"

exit 0;
