#!/bin/bash

### File name: WhoOccupySLURM.sh 
### Developer: Seyed Nariman Saadatmand 
### Contact: nariman.saadatmand@uq.edu.au  
### Kick-started in: 19/Sep/2016
### Descrption: this program uses customized 'squeue' commands to report how many CPU threads each user is 
### occupying and how many free threads are left for a specific partition of a slurm-managed cluster (currently,
### the program reports usage statistics of 'smp' partition on DOGMATIX).
VER="1.3.18"

echo "Preparing the CPU usage statistics of the 'smp' partition of DOGMATIX for all users:" # the initial message

### a function that checks the existence of array elements:
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
declare -a user_jobsR=()
declare -a user_jobsPD=()
declare -a user_cpus=()

mktemp 1> /dev/null; temp="$(mktemp)";

### the main command to get the user statistics:
squeue -p smp -o "%u %t %C %D" > $temp
sed -i 1d $temp
#SplitLine=`awk '$5=="qw" {print NR; exit;}' $temp`
#let SplitLine--
#split --lines=${SplitLine} ${temp} ${temp}_
#N=$(wc -l < "${temp}_aa")
N=$(wc -l < "$temp")

i=0
j=0
while read -r line; do 

   let i++
   progress=`echo "scale=0; (${i}*100)/${N}" | bc -q`
   echo -en "\rworking %$progress ..."

   #ID=`echo $line | awk '{print $1}'`
   #q_name=`echo $line | awk '{print $8}'`
   #q_name=${q_name%@*}

   #echo "DEBUG: for line=${i}, we have ID= \"${ID}\", state=\"${state}\", and q_name=\"${q_name}\" ..."

   user_test=`echo $line | awk '{print $1}'`
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

   state=`echo $line | awk '{print $2}'`
   cpus=`echo $line | awk '{print $3}'`
   
   if [ "$state" == 'R' ]; then
     user_jobsR[$this_index]=$(( ${user_jobsR[$this_index]} + 1 ))
     user_jobsR[9999]=$(( ${user_jobsR[9999]} + 1 ))
     user_cpus[$this_index]=$(( ${user_cpus[$this_index]} + ${cpus} ))
     user_cpus[9999]=$(( ${user_cpus[9999]} + ${cpus} ))
     user_jobsPD[$this_index]=$(( ${user_jobsPD[$this_index]} + 0 ))
     user_jobsPD[9999]=$(( ${user_jobsPD[9999]} + 0 ))
   elif [ "$state" == 'PD' ]; then
     user_jobsR[$this_index]=$(( ${user_jobsR[$this_index]} + 0 ))
     user_jobsR[9999]=$(( ${user_jobsR[9999]} + 0 ))
     user_cpus[$this_index]=$(( ${user_cpus[$this_index]} + 0 ))
     user_cpus[9999]=$(( ${user_cpus[9999]} + 0 ))
     user_jobsPD[$this_index]=$(( ${user_jobsPD[$this_index]} + 1 ))
     user_jobsPD[9999]=$(( ${user_jobsPD[9999]} + 1 ))
   fi

   #echo "DEBUG0: in line=${i}, we have user=${user[$this_index]}, name=${name[$this_index]}, jobs_running=${user_jobsR[$this_index]}, jobs_pending=${user_jobsPD[$this_index]}, and cpus=${user_cpus[$this_index]} ..."

done < ${temp}

# inserting some additional data for all_users:
user[9999]="all_users"
name[9999]="--"

# printing final results in a desirley-formatted table:
mktemp 1> /dev/null; temp2="$(mktemp)";
echo -e "\n\n#user\t#registered_name\t#jobs_total\t#jobs_running\t#jobs_pending\t#occupied_CPUs/TOTAL"
echo "------------------------------------------------------------------------------------------------------------"

for k in "${!user[@]}"; do
   #echo "DEBUG1: for index=$k, we have user=${user[$k]}, name=${name[$k]}, jobs_running=${user_jobsR[$k]}, jobs_pending=${user_jobsPD[$k]}, and cpus=${user_cpus[$k]} ..."
   #if [ -z ${user_slots[$k]} ]; then user_slots[$k]=0; fi
   #if [ -z ${user_slots1[$k]} ]; then user_slots1[$k]=0; fi
   jobs_total=$(( ${user_jobsR[$k]} + ${user_jobsPD[$k]} ))
   printf "%9s\t%20s\t%i\t%i\t%i\t%i/1220\n" ${user[$k]} "${name[$k]}" ${jobs_total} ${user_jobsR[$k]} ${user_jobsPD[$k]} ${user_cpus[$k]} >> $temp2
done

#cat $temp2
sort -k7 -n -r $temp2

echo "------------------------------------------------------------------------------------------------------------"

exit 0;
