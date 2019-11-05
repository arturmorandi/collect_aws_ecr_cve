#!/bin/bash
#
# Gets AWS ECR repositories and show the CVEs/findings detected
# Author: Artur Morandi
# Pitfalls: Checks only the latest image
#
#Instructions:
#1. Enable Image Scanning on your ECR repositories
#2. Create the S3 bucket
#3. Create the Slack App and give it webhooks and chat:bot:write permissions
#4. Change variables between "<>"
#

IFS=$'\n\t'

reponame=( $(aws ecr describe-repositories | jq .repositories[].repositoryName -r) )
logbucket="<AWS_S3_LOG_BUCKET>"
logfile="<LOG_PREFIX>_$(date +%Y%m%d_%H%M%S).txt"
rundir=$(pwd)

#Gets findings for each repo
function getcves () {
	cvecount=0
	while (( $cvecount != ${#repocves[*]} )); do
		echo -e "CVE:${repocves[$cvecount]}; SEV:${reposvrt[$cvecount]}; PKG:${repopkgs[$cvecount]}" >> $rundir/$logfile
		cvecount=$cvecount+1
	done
}

#Checks status of image scanning feature and call getcves()
function main () {
	repocount=0
	scanstate=$(aws ecr describe-image-scan-findings --repository-name $repo --image-id imageTag=$(aws ecr describe-images --repository-name $repo | jq -r ".imageDetails[].imageTags" | grep -v "null" | jq -r .[] | head -1) | jq -r ".imageScanStatus.status" | grep COMPLETE)
	scanstatus=$(aws ecr describe-repositories --repository-name $repo | jq .repositories[].imageScanningConfiguration.scanOnPush -r | awk '{sub("true","ENABLED"); sub("false","DISABLED"); print}' | grep "ENABLED")
	imgname=$(aws ecr describe-images --repository-name $repo | jq -r ".imageDetails[].imageTags" | grep -v "null" | jq -r .[] | head -1)

	if [ -z $scanstate ] || [ -z $scanstatus ]; then
		echo -e "[ ! WARNING ! ] Repository ${repo^^} with status ${scanstatus^^} doesn't look good. Please enable ECR Image Scanning or check manually!\n" >> $rundir/$logfile
		repocount=$repocount+1;
	else
		while (( $repocount != ${#reponame[*]} )); do
			repocves=( $(aws ecr describe-image-scan-findings --repository-name $repo --image-id imageTag=$(aws ecr describe-images --repository-name $repo | jq -r ".imageDetails[].imageTags" | grep -v "null" | jq -r .[] | head -1) | jq -r '.imageScanFindings.findings[].name') )
			reposvrt=( $(aws ecr describe-image-scan-findings --repository-name $repo --image-id imageTag=$(aws ecr describe-images --repository-name $repo | jq -r ".imageDetails[].imageTags" | grep -v "null" | jq -r .[] | head -1) | jq -r '.imageScanFindings.findings[].severity') )
			repopkgs=( $(aws ecr describe-image-scan-findings --repository-name $repo --image-id imageTag=$(aws ecr describe-images --repository-name $repo | jq -r ".imageDetails[].imageTags" | grep -v "null" | jq -r .[] | head -1) | jq -r '.imageScanFindings.findings[].attributes[] | select(.key=="package_name") | .value') )

			echo -e "-=(( Repository: ${repo^^} | Image: $imgname ))=-" >> $rundir/$logfile
			getcves
			repocount=$repocount+1
			echo -e "\n" >> $rundir/$logfile
			break
		done
	fi
}

#Sends log to AWS Bucket and posts message in Slack channel
function sendlog () {
	local logurl=$(aws s3 presign s3://$logbucket/$logfile --expires-in <SECONDS_BEFORE_S3_PRESIGNED_URL_EXPIRES>)

	aws s3 cp $rundir/$logfile s3://$logbucket/$logfile

slack_msg()
{
cat <<EOF
{
    "username": "<USERNAME_TO_SHOW_ON_POST>",
    "channel": "<SLACK_CHANNEL>",
    "as_user": "false",
    "icon_url": "<POST_ICON>",
    "attachments": [
        {
            "pretext": "AWS ECR Image Scan Results",
            "color": "#ff0000",
            "fields": [
                {
                    "value": "${#reponame[*]} repositories scanned.",
                    "short": false
                }
        ],
        "actions": [
            {
                "type": "button",
                "text": "$logfile",
                "url": "$logurl"
            }
        ],
        "footer": "Document link valid for 8 hours",
        "ts": "`date +%R`"
        }
                   ]
}
EOF
}

	local slackmsgfile=$(mktemp)
	slack_msg > $slackmsgfile

	curl -X POST -H 'Authorization: Bearer <INSERT_SLACK_OAUTH_TOKEN_HERE>' -H 'Content-type: application/json; charset=utf8' --data "$(cat $slackmsgfile)" https://slack.com/api/chat.postMessage
	rm -rf $slackmsgfile
}

#MAIN LOGIC
for repo in ${reponame[*]}; do
    main
done

sendlog
rm -rf $rundir/$logfile
