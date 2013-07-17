#!/bin/bash
#
# This script has been adapted from the drush wrapper script + WP base install scratch
# and credits should go to the authors of those projects:
# http://drupal.org/project/drush
# https://gist.github.com/3157720

# Get the absolute path of this executable
ORIGDIR=$(pwd)
SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P) && SELF_PATH=$SELF_PATH/$(basename -- "$0")
WP_TOOLS_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)


# Resolve symlinks - this is the equivalent of "readlink -f", but also works with non-standard OS X readlink.
while [ -h "$SELF_PATH" ]; do
	# 1) cd to directory of the symlink
	# 2) cd to the directory of where the symlink points
	# 3) Get the pwd
	# 4) Append the basename
	DIR=$(dirname -- "$SELF_PATH")
	SYM=$(readlink $SELF_PATH)
	SELF_PATH=$(cd $DIR && cd $(dirname -- "$SYM") && pwd)/$(basename -- "$SYM")
done
cd "$ORIGDIR"
echo "Working in $ORIGDIR"

# http://sterlinghamilton.com/2010/12/23/unix-shell-adding-color-to-your-bash-script/
# Example usage:
# echo -e ${RedF}This text will be red!${Reset}

Colors() {
	Escape="\033";
	BlackF="${Escape}[30m";   RedF="${Escape}[31m";   GreenF="${Escape}[32m"; YellowF="${Escape}[33m";  BlueF="${Escape}[34m";  Purplef="${Escape}[35m"; CyanF="${Escape}[36m";  WhiteF="${Escape}[37m"; 
	Reset="${Escape}[0m";
}
Colors;

# PROJECT init
echo -e ${YellowF}"Project Name:"${Reset}
read -e PROJECT_NAME


PREP_SLUG=${PROJECT_NAME//[^a-zA-Z0-9\-]/-}
PROJECT_FOLDER=$(echo ${PREP_SLUG} | tr '[A-Z]' '[a-z]')
PROJECT_DB_NAME=${PROJECT_FOLDER//[^a-zA-Z0-9]/_}
PROJECT_SLUG=$(${WP_TOOLS_PATH}/db-name-sani.php ${PREP_SLUG})

echo -e ${YellowF}"Project slug (lowercase, no spaces, 2-4 characters) [${PROJECT_SLUG}]:"${Reset}
read -e PROJECT

if [ -z "$PROJECT"] ; then
		PROJECT=$PROJECT_SLUG
	fi

HTTPDOCS="$ORIGDIR/$PROJECT_FOLDER"
CNF="$ORIGDIR/$PROJECT"

# Create Project REPO

echo -e ${YellowF}"Create Project Repo? Bitbucket (y/n):"${Reset}
read -e SETUP_REPO

if [ "$SETUP_REPO" == "y" ] ; then
	echo "Owner (Leave blank if not team): "
	read -e BB_Owner
	echo "Username: "
	read -e BB_USER
	echo "Password: "
	read -s BB_PASS

	curl -u$BB_USER:$BB_PASS -X POST -d "name=$PROJECT_NAME" -d "owner=$BB_Owner" -d 'is_private=1' -d 'scm=git' https://api.bitbucket.org/1.0/repositories/

	git clone https://$BB_USER:$BB_PASS@bitbucket.org/$BB_Owner/$PROJECT_FOLDER.git $HTTPDOCS

	GIT_PATH="$HTTPDOCS/.git/hooks"
fi

if [ "$SETUP_REPO" != "y" ] ; then
	mkdir $HTTPDOCS
fi

cd $HTTPDOCS



echo -e ${YellowF}"Creating LOCAL MySQL DB"${Reset}

echo "Database Name: [$PROJECT_DB_NAME]"

echo "Database User: "
read -e LOCAL_DB_USER
echo "Database Password: "
read -s LOCAL_DB_PASS

if [ "$SETUP_REPO" == "y" ] ; then
	echo -e ${YellowF}"Adding git hooks for DB VCS"${Reset}
	cp $WP_TOOLS_PATH'/skeleton/pre-commit' $GIT_PATH'/pre-commit'
	sed -i.bak 's/dbuser/'$LOCAL_DB_USER'/g' $GIT_PATH/pre-commit
	sed -i.bak 's/dbpassword/'$LOCAL_DB_PASS'/g' $GIT_PATH/pre-commit
	sed -i.bak 's/dbname/'$PROJECT_DB_NAME'/g' $GIT_PATH/pre-commit
	sed -i.bak 's|projectpath|'$HTTPDOCS'|g' $GIT_PATH/pre-commit
	chmod +x $GIT_PATH/pre-commit

	cp $WP_TOOLS_PATH'/skeleton/post-merge' $GIT_PATH'/post-merge'
	sed -i.bak 's/dbuser/'$LOCAL_DB_USER'/g' $GIT_PATH/post-merge
	sed -i.bak 's/dbpassword/'$LOCAL_DB_PASS'/g' $GIT_PATH/post-merge
	sed -i.bak 's/dbname/'$PROJECT_DB_NAME'/g' $GIT_PATH/post-merge
	sed -i.bak 's|projectpath|'$HTTPDOCS'|g' $GIT_PATH/post-merge
	chmod +x $GIT_PATH/post-merge
fi

## Get WordPress
echo -e ${YellowF}"Running wp core download in httpdocs..."${Reset}
cd "$HTTPDOCS"
wp core download
wp db create
echo -e ${GreenF}"WordPress Core downloaded"${Reset}

rm wp-config-sample.php
rm README.txt
rm license.txt

#TODO: Autogenerate SALTS?
#SECRET_KEYS="wget https://api.wordpress.org/secret-key/1.1/salt"
#sed -i.bak 's/WPT_SECRET_KEYS/'$SECRET_KEYS'/g' ./wp-config.php



# Install site
echo -e ${YellowF}"Installing WordPress..."${Reset}

echo "URL [http://127.0.0.1/$PROJECT_FOLDER]: "
read -e SITEURL
	if [ -z "$SITEURL"] ; then
		SITEURL="http://127.0.0.1/$PROJECT_FOLDER"
	fi
echo "Title: "
read -e SITETITLE
echo "Admin Name: "
read -e SITEADMIN_NAME
echo "Admin Username: "
read -e SITEADMIN
echo "E-mail: "
read -e SITEMAIL
echo "Site Password: "
read -s SITEPASS

echo "Install site? (y/n)"
read -e SITERUN
if [ "$SITERUN" != "y" ] ; then
  exit
fi

wp core install --url=$SITEURL --title=$SITETITLE --admin_name=$SITEADMIN --admin_email=$SITEMAIL --admin_password=$SITEPASS

wp rewrite structure %category%/%postname%

## Install plugins

wp plugin install backwpup
wp plugin install developer
wp plugin install google-analytics-for-wordpress
wp plugin install advanced-custom-fields
wp plugin install rewrite-rules-inspector

wget https://github.com/CaavaDesign/caava-helper/archive/master.zip -O master.zip
wp plugin install master.zip
rm master.zip

wp plugin delete hello
wp plugin delete akismet

wp plugin update-all

echo "Install _s theme? (y/n)"
read -e THEME_INSTALL

if [ "$THEME_INSTALL" != "y" ] ; then
  exit
fi

echo "Admin Website: "
read -e SITEADMIN_URI

echo ${YellowF}"Installing _S Theme with project information..."

THEME_DIR="$HTTPDOCS/wp-content/themes/$PROJECT_SLUG"
SASS_DIR="$THEME_DIR/scss"


## Install theme
wp scaffold _s $PROJECT_SLUG --theme_name="$SITETITLE" --author="$SITEADMIN_NAME" --author_uri="$SITEADMIN_URI" --activate
cd "$HTTPDOCS"



git clone --recursive git@github.com:csswizardry/inuit.css-web-template.git $SASS_DIR
cd $SASS_DIR
mv css/* .
rm -rf README.md .git .gitmodules go index.html css watch
wget https://raw.github.com/csswizardry/csswizardry-grids/master/csswizardry-grids.scss -O $SASS_DIR/csswizardry-grids.scss

cd $THEME_DIR
touch front-page.php

# Server user and group
#chown www-data * -R
#chgrp www-data * -R