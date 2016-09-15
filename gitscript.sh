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
PULL_AFTER_CLONE=true									# pull or not after git init

DB_USER="root"											# mysql user
DB_PASSWORD=""											# mysql password
DB_NAME=""												# if not setted, the script will not import the db
DB_TO_IMPORT=""											# latest_dump.sql # name of the sql file to import
SITE_URL="http://localhost/"							# site url: wp_options will be updated with this value
CACHE_PW=true											# cache or not user password (of git)
SITE_DIR=""												# directory of repository (relative path)
DB_DIR="data"											# directory where the sql file to import is located
IS_WORDPRESS=true										# update or not wp_options table of wordpress and wp-config file
IMPORT_DB_AFTER_PULL=true								# import or not database after pull command

function init {
	# se viene passato come parametro 'here', viene fatto il "clone" all'interno della cartella stessa
	# es. sh gitinit.sh here
	if [ "$1" = "here" ] || [ "$DIR_TO_CLONE" = "." ]; then
		git init .
		# enable or not git credential cache
		cache_password
		git remote add -t \* -f origin $GIT_URL
		git checkout master
		if $PULL_AFTER_CLONE; then
			echo "git init end: pulling latest version"
			pull
		fi
		exit
	fi

	if [ -d "$DIR_TO_CLONE" ]; then
		# Control will enter here if $DIRECTORY exists.
		echo "Directory just exists, do you want continue?. Clone on non-empty folder will fail!"
		askYN
		if ! $AREYOUSURE; then
			echo "exiting..."; exit;
		else
			cd $DIR_TO_CLONE
		fi
	else
		mkdir $DIR_TO_CLONE
	fi

	# clone repository
	git clone $GIT_URL $DIR_TO_CLONE
	# go to the directory with the cloned repository
	cd $DIR_TO_CLONE
	# checkout master branch
	git checkout master
	# do fetch
	git fetch --all
	# change config.php file from development to production version
	changeConfigFile
	echo "done"
	exit
}

function pull {
	echo "Pulling from repository $GIT_URL from branch $BRANCH_TO_PULL"
	askYN "Continue?"
	if ! $AREYOUSURE; then
		echo "exiting..."; exit;
	fi
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
	# change config.php file from development to production version
	changeConfigFile
	# import db if his name is setted
	if [ "$IMPORT_DB_AFTER_PULL" ]; then
		echo "IMPORT_DB_AFTER_PULL variable is set to TRUE"
		echo "If you continue $DB_TO_IMPORT (in $DB_DIR directory) will be imported in $DB_NAME database"
		askYN "Are you sure?"
		if ! $AREYOUSURE; then
			echo "exiting..."; exit;
		fi
		cd $DB_DIR
		mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < $DB_TO_IMPORT;
		if $IS_WORDPRESS; then
			QUERY="UPDATE wp_options SET option_value = '$SITE_URL' WHERE option_name = 'siteurl' OR option_name = 'home';"
			mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "$QUERY"
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
		#cd $DB_DIR
		mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > "$DB_DIR/$DATE.sql"
		echo "database exported succesfully in $DB_DIR/$DATE.sql"
		read -p "Do you want to commit and push exported database? (y/N) " yn
	    case $yn in
	        [Yy]* ) 
				git add $DB_DIR/$DATE.sql
				git commit -m 'mysqldump'
				git push --all
				echo "push on $BRANCH_TO_PULL successfully"
				;;
	        [Nn]*|* ) ;;
	    esac
	else
		echo "$DB_NAME is not setted, dump database failed"
		echo "exiting..."
		exit
	fi
}

function importdb {
	read -e -p "which file do you want to import? " SQLFILE
	# if ! [ -f $SQLFILE ]; then
	# 	echo "file doens't exist"
	# 	importdb
	# 	return 0
	# fi
	askYN "Database name is $DB_NAME, it's correct?"
	if ! $AREYOUSURE; then
		read -p "What is the database name?" DB_NAME
	fi
	askYN "Are you sure to import $SQLFILE to $DB_NAME?"
	mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < $SQLFILE;
	changeConfigFile
	updateSiteUrl
	echo "exiting..."
}

function updateSiteUrl {
	askYN "Do you want update siteurl value?"
	if $AREYOUSURE; then
		QUERY="UPDATE wp_options SET option_value = '$SITE_URL' WHERE option_name = 'siteurl' OR option_name = 'home';"
		mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "$QUERY"
	fi
}

function changeConfigFile {
	askYN "Do you want change wp-config files?"
	if $AREYOUSURE; then
		mv wp-config.php wp-config.development.php
		mv wp-config.production.php wp-config.php
		echo "wp-config renamed succesfully"
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


function askYN {
	if [[ "$1" ]] && [[ "$1" != "noecho" ]]; then
		ECHOSTRING="$1"
	else
		ECHOSTRING=""
	fi
	echo -n -e "$1 (y/N)\n"
	read -p "" yynn
	case $yynn in
        [Yy]* ) AREYOUSURE=true; ;;
        [Nn]*|* ) AREYOUSURE=false; ;;
        #* ) echo "Please answer yes or no.";;
    esac
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
	"askYN")
		askYN "Continue?"
		;;
	*)
		echo "What do you want to do? Write the option number:"
		select answer in "init" "init here" "pull" "dump database" "import database" "update siteurl" "exit"; do
		    case $answer in
		        "init" ) init; break;;
		        "init here" ) init here; break;;
		        "pull" ) pull; break;;
		        "dump database" ) dump; break;;
		        "import database" ) importdb; break;;
				"update siteurl" ) updateSiteUrl; break;;
		        "exit" ) echo "exiting..."; exit;;
				*) echo "invalid option";;
		    esac
		done
		;;
esac
