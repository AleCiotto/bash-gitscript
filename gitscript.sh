#/****************************************************************************/#
#/*                                                                          */#
#/*  Author:   Alessandro Mercurio                                           */#
#/*  Version:  0.1                                                           */#
#/*  Site: alessandromercurio.it                                             */#
#/*  Copyright © 2016 - MIT License                                          */#
#/*                                                                          */#
#/****************************************************************************/#

GIT_URL=""												# git repository url
BRANCH_TO_PULL="master"									# branch name to checkout/pull
DIR_TO_CLONE="."										# directory where the repository will be cloned
PULL_AFTER_CLONE=false									# pull or not after git init

DB_USER="root"											# mysql user
DB_PASSWORD=""											# mysql password
DB_NAME=""												# if not setted, the script will not import the db
DB_TO_IMPORT=""											# latest_dump.sql # name of the sql file to import
SITE_URL="http://localhost/"							# site url: wp_options will be updated with this value
CACHE_PW=true											# cache or not user password (of git)
SITE_DIR=""												# directory of repository (relative path)
DB_DIR="data"											# directory where the sql file to import is located
IS_WORDPRESS=true										# update or not wp_options table of wordpress and wp-config file
IMPORT_DB_AFTER_PULL=false								# import or not database after pull command

function init {
	# se viene passato come parametro 'here', viene fatto il "clone" all'interno della cartella stessa
	# es. sh gitinit.sh here
	if [ "$1" = "here" ]; then
		git init .
		# enable or not git credential cache
		cache_password
		git remote add -t \* -f origin $GIT_URL
		git checkout master
		if $PULL_AFTER_CLONE; then
			echo "script end: pulling latest version"
			sh $PULL_SCRIPT_NAME
		fi
		exit
	fi

	mkdir $DIR_TO_CLONE
	# clone repository
	git clone $GIT_URL $DIR_TO_CLONE
	# go to the directory with the cloned repository
	cd $DIR_TO_CLONE
	# checkout master branch
	git checkout master
	# do fetch
	git fetch --all
	if $PULL_AFTER_CLONE; then
		echo "script end: pulling latest version"
		cd $DIR_TO_CLONE
		sh $PULL_SCRIPT_NAME
	else
		echo "script end: run the other script if you want to pull latest version"
	fi
	exit
}

function pull {
	# enable or not git credential cache
	cache_password
	# git fetch
	git fetch --all
	echo "fetching finished"
	# git pull (hard reset)
	git reset --hard origin/$BRANCH_TO_PULL
	echo "branch reset succesfully"
	# change wp-config settings with prodution/demo data
	if [ "$SITE_DIR" ]; then
		cd $SITE_DIR
	fi
	if [ "$IS_WORDPRESS" ]; then
		mv wp-config.php wp-config.development.php
		mv wp-config.production.php wp-config.php
		echo "wp-config renamed succesfully"
	fi
	# import db if his name is setted
	if [ "$IMPORT_DB_AFTER_PULL" ]; then
		# import DB and change wordpress variables
		cd $DB_DIR
		mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < $DB_TO_IMPORT;
		if $IS_WORDPRESS; then
			mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "UPDATE wp_options SET option_value = '$SITE_URL' WHERE option_name = 'siteurl' OR option_name = 'home';"
			echo "db imported and siteurl updated"
		else
			echo "db imported"
		fi
	else
		echo "db name is not valid or empty, db will be not imported"
	fi
	exit
}

function dump {
	if [ "$DB_NAME" ]; then
		DATE=`date +%Y-%m-%d_%H-%M-%S`						# get date in format yyyy-mm-dd_HH-MM-SS
		cd $DB_DIR
		mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > "$DATE.sql"
		echo "database exported succesfully in $DB_DIR/$DATE.sql"
	else
		echo "$DB_NAME is not setted, dump database failed"
		echo "exiting..."
		exit
	fi
}

function cache_password {
	if [ "$CACHE_PW" ]; then
		git config credential.helper cache
		echo "password will be cached (900 seconds by default)"
	else
		echo "password cache is disabled"
	fi
}

### BODY ###

case $1 in
	"init")
		init $2
		break
		;;
	"pull")
		pull $2
		break
		;;
	*)
		echo "What do you want to do? Write the option number:"
		select answer in "init" "init here" "pull" "dump database" "exit"; do
		    case $answer in
		        "init" ) init; break;;
		        "init here" ) init here; break;;
		        "pull" ) pull; break;;
		        "dump database" ) dump; break;;
		        "exit" ) echo "exiting..."; exit;;
				*) echo "invalid option";;
		    esac
		done
		;;
esac
