#!/bin/bash

remote_user="PacificBiosciences"
remote_repo="pb-human-wgs-workflow-wdl"

local_user=$1
local_repo="pb-human-wgs-workflow-wdl"

echo "Info:"
echo -e "\tremote_user: ${remote_user}"
echo -e "\tremote_repo: ${remote_repo}"
echo -e "\t local_user: ${local_user}"
echo -e "\t local_repo: ${local_repo}"
echo " "
echo -e "\tTo change the local and remote URLs, please edit this '$0' script."
echo " "
echo " "

if [ $# -eq 2 ] && [ "$2" == "--remote" ]; then
	echo -en "Changing all WDL Github URLs from '${local_user}/${local_repo}' to '${remote_user}/${remote_repo}'..."
	find . -type f -name "*.wdl" -print0 | \
		xargs -0 sed -i "s/com\/${local_user}\/${local_repo}/com\/${remote_user}\/${remote_repo}/g"
	echo "done!"

elif [ $# -eq 2 ] && [ "$2" == "--local" ]; then
	echo -en "Changing all WDL Github URLs from '${remote_user}/${remote_repo}' to '${local_user}/${local_repo}'..."
	find . -type f -name "*.wdl" -print0 | \
		xargs -0 sed -i "s/com\/${remote_user}\/${remote_repo}/com\/${local_user}\/${local_repo}/g"
	echo "done!"

else
	echo "Usage:"
	echo " "
	echo "./rename_urls.sh local_user --remote"
	echo -e "\t\tChange all WDL Github URLs from '${local_user}/${local_repo}' to '${remote_user}/${remote_repo}'"
	echo "./rename_urls.sh local_user --local"
	echo -e "\t\tChange all WDL Github URLs from '${remote_user}/${remote_repo}' to '${local_user}/${local_repo}'"

fi
