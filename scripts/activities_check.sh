#!/bin/bash
# Prerequisite
# brew install datediff
# brew install jq
# aws configure 

ASG_NAME=$1

if [ -n "$ASG_NAME" ]
then
    activities=$(aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASG_NAME --output json)
    for row in $(echo $activities | jq -r '.Activities[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
    start_time=$(_jq '.StartTime')
    end_time=$(_jq '.EndTime')
    activity=$(_jq '.Description')
    echo $activity Duration: $(datediff $start_time $end_time)
    done
else
    echo "Usage: sh ./activities_check.sh ASG_NAME"
fi