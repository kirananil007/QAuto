#!/bin/bash
# Name : Wrapper script
# Use : Get info from user do checks pass it to ansible
# Version : 0.1
# By : Hossan

################## VAR's
SSH=`which ssh`
LOGIN_USER=kiran
CONF=qa_env
QA=ansible
QA_SERVER=`cat $CONF | grep -A1 $QA | grep -v $QA`
JEN=jenkinserver
JEN_SERVER=`cat $CONF | grep -A1 $JEN| grep -v $JEN`
CONF_LOC='/etc/apache2/sites-available'
JEN_JOB='/var/lib/jenkins/jobs'
GIT_USER='kirananil007'

################# Functions
get_user(){
user=`echo $1 |rev| cut -f3- -d.|rev|tr -cd '[[:alnum:]]'|sed 's/\(.\{10\}\).*/\1/'`
$SSH $QA_SERVER -l $LOGIN_USER 'cat /etc/passwd| cut -f1 -d:' > /tmp/test
## Error check for above command
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi 
for i in `cat /tmp/test`;do
	if [[ $i =~ ^$user$ ]]; then
		return 25
	fi
done
echo $user
}

check_vhost(){
if $SSH $LOGIN_USER@$QA_SERVER stat $CONF_LOC/$1-deploy.conf \> /dev/null 2\>\&1 
	then
	return 35
fi
}

check_jobdir(){
if $SSH $LOGIN_USER@$JEN_SERVER stat $JEN_JOB/$1 \> /dev/null 2\>\&1
	then
	return 45
fi
}

check_ansible(){
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ansible|grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
  echo -e "Provisioner :\e[31m $PROV Not available\e[0m"
  read -r -p "Please confirm if you want me to install ansible : [y/N] " response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
   echo -e "Installing: \e[32mAnsible\e[0m"
   sudo apt-get --force-yes --yes install ansible
else
   echo -e "Provisioner :\e[31m Sorry, need ansible to run\e[0m"
   exit
fi
fi
}

ansible_call(){
ANSIBLE=`which ansible-playbook`
$ANSIBLE -i $CONF site.yml --extra-vars "sub_domain=$1 git_url=$2 git_pro=$3 user=$4"
}


print_ansible(){
### Print the ansible code used to build this
echo -e "\n\n\n ***************************************************************************************"
echo -e "\e[32m$ANSIBLE -i $CONF site.yml --extra-vars \"sub_domain=$sub_domain git_url=$git_huburl git_pro=$git_prourl user=$user\"\e[0m"
echo -e "You can use the above command line to reset the project state to default one"
echo -e "*************************************************************************************** \n\n\n"
}

################### Main section
## Checks to verify the arguments


if [[ "$#" -ne 2 ]]; then
	if [[ ( "$1" == "-h" || "$1" == "--help" || "$1" == "" ) ]]; then
		echo -e "\n Usage : \e[32m./`basename $0` <subdomain.qburst.com> <github_repo_url>\e[0m\n"
  		exit 0
	else
		echo -e "Argument check : \e[31mPlease enter right number of arguments\e[0m"
		echo -e " Usage : \e[32m./`basename $0` <subdomain.qburst.com> <github_repo_url>\e[0m\n"
		exit 0
	fi
fi
if [[ $1 =~ ^[a-zA-Z0-9\.]+\.qburst.com$ && $2 =~ ^https://github.com/$GIT_USER/[[:alnum:].]+\.git ]]; then
	sub_domain="$1"
	git_huburl="$2"
	git_prourl=`echo $2| rev | cut -d. -f2- | rev`
else
	echo -e "Syntax check : \e[31mArgument Syntax wrong\e[0m"
	echo -e "Usage : \e[32m./`basename $0` <subdomain.qburst.com> <github_repo_url>\e[0m\n"
	exit 0
fi

###Check if the subdomain user exists in the QA server 
user=`get_user $sub_domain`
## Error check for above command
rc=$?; if [[ $rc = 25 ]]; then 
	echo -e "User exist : \e[31mPlease attempt manual ansible run\e[0m"
	echo -e "Use syntax : \e[32mansible -i $CONF site.yml --extra-vars \"sub_domain=$sub_domain git_url=$git_huburl git_pro=$git_prourl user=your_user\"\e[0m"
	exit $rc; 
fi
echo -e "User check pass : \e[32m$user\e[0m"

###Check if the VHOST for the subdomain is already in the server
check_vhost $sub_domain
rc=$?; if [[ $rc = 35 ]]; then 
	echo -e "Vhost check : \e[31m Please check QA server if Vhost exist\e[0m"
	exit $rc; 
fi
echo -e "Vhost check pass : \e[32m$CONF_LOC/$1-deploy.conf\e[0m"

###Check if the job for the subdomain is already in the server
check_jobdir $sub_domain
rc=$?; if [[ $rc = 45 ]]; then
        echo -e "Job check : \e[31m Please check Jenkins server if Job already exist\e[0m"
        exit $rc;
fi
echo -e "Job check pass : \e[32m$JEN_JOB/$sub_domain\e[0m"


### Info and decision section
echo -e "Subdomain you provided : \e[32m$sub_domain\e[0m"
echo -e "Git url you provided : \e[32m$git_huburl\e[0m"
echo -e "Git project url : \e[32m$git_prourl\e[0m"
read -r -p "Please confirm to proceed : [y/N] " response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
   check_ansible # check/install ansible 
   echo -e "Handing the info over to provisioner : \e[32mAnsible\e[0m"
   ansible_call $sub_domain $git_huburl $git_prourl $user 
else
   echo -e "Bye bye"
   exit 
fi

### Print the ansible code
print_ansible
