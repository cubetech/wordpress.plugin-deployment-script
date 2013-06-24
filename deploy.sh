#!/bin/bash
#
# Script to deploy from Github to WordPress.org Plugin Repository
# Author: cubetech GmbH, www.cubetech.ch
# Forked from thenbrent, thanks!
# Source: https://github.com/cubetech/wordpress.plugin-deployment-script

#prompt for plugin slug and check if directory exists
if [ -z "$1" ]
then
	echo -e "Plugin Slug: \c"
	read -e PLUGINSLUG
else
	PLUGINSLUG="$1"
fi

if [ ! -d "$PLUGINSLUG" ]
then
	if [ ! -d "${PWD}/$PLUGINSLUG" ]
	then
		echo "Folder '$PLUGINSLUG' does not exist. Exiting...."
		exit 1
	fi
fi 

# main config, set off of plugin slug
CURRENTDIR=`pwd`
CURRENTDIR="$CURRENTDIR/$PLUGINSLUG"
MAINFILE="$PLUGINSLUG.php" # this should be the name of your main php file in the wordpress plugin

# git config
GITPATH="$CURRENTDIR/" # this file should be in the base of your git repository

# svn config
SVNPATH="/tmp/$PLUGINSLUG" # path to a temp SVN repo. No trailing slash required and don't add trunk.
SVNURL="http://plugins.svn.wordpress.org/$PLUGINSLUG/" # Remote SVN repo on WordPress.org, with no trailing slash
SVNUSER="XXX" # your svn username
SVNPASS="XXX" # your svn password

# Let's begin...
echo "..........................................................."
echo 
echo "WordPress plugin deployment script"
echo "Developed by cubetech GmbH, www.cubetech.ch"
echo
echo "Preparing to deploy WordPress plugin:"
echo "$PLUGINSLUG"
echo 
echo "..........................................................."
echo 

# Check if SVN settings are set
if [ "$SVNUSER" == "XXX" ]; then echo "Please update your SVN auth settings! Exiting..."; exit 1; fi

# Check if files properly exists
if [ ! -f "$GITPATH/$MAINFILE" ]; then echo "Plugin is not properly developed. Needed file '$GITPATH$MAINFILE' does not exists. Exiting...."; exit 1; fi
if [ ! -f "$GITPATH/readme.txt" ]; then echo "Plugin is not properly developed. Needed file '$GITPATH/readme.txt' does not exists. Exiting...."; exit 1; fi

# Check version in readme.txt is the same as plugin file
NEWVERSION1=`grep "^Stable tag" $GITPATH/readme.txt | awk -F' ' '{print $3}'`
echo "readme version: $NEWVERSION1"
NEWVERSION2=`grep "^Version" $GITPATH/$MAINFILE | awk -F' ' '{print $2}'`
echo "$MAINFILE version: $NEWVERSION2"

if [ `egrep -l $'\r'\$ $GITPATH/readme.txt` ] || [ `egrep -l $'\r'\$ $GITPATH/$MAINFILE` ]; then echo "STOP! There are files with windows line ending. Please clean this up! Exiting...."; exit 1; fi

if [ "$NEWVERSION1" != "$NEWVERSION2" ]; then echo "Versions don't match. Exiting..."; exit 1; fi

echo "Versions match in readme.txt and PHP file. Let's proceed..."

cd $GITPATH
echo -e "Enter a commit message for this new version: \c"
read -e COMMITMSG
git commit -am "$COMMITMSG"

echo "Tagging new version in git"
git tag -a "$NEWVERSION1" -m "Tagging version $NEWVERSION1"

echo "Pushing latest commit to origin, with tags"
git push origin master
git push origin master --tags

echo 
echo "Creating local copy of SVN repo ..."
svn co $SVNURL $SVNPATH

echo "Ignoring github specific files and deployment script"
svn propset svn:ignore "deploy.sh
README.md
.git
.gitignore
banner-772x250.*
banner-1544x500.*" "$SVNPATH/trunk/"

#export git -> SVN
echo "Exporting the HEAD of master from git to the trunk of SVN"
git checkout-index -a -f --prefix=$SVNPATH/trunk/

#if submodule exist, recursively check out their indexes
if [ -f ".gitmodules" ]
then
echo "Exporting the HEAD of each submodule from git to the trunk of SVN"
git submodule init
git submodule update
git submodule foreach --recursive 'git checkout-index -a -f --prefix=$SVNPATH/trunk/$path/'
fi

echo "Changing directory to SVN and committing to trunk"
cd $SVNPATH/trunk/
# Add all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2}' | xargs svn add
svn commit --username=$SVNUSER --password=$SVNPASS -m "$COMMITMSG"

echo "Creating new SVN tag & committing it"
cd $SVNPATH
if [ ! -d "tags/$NEWVERSION1/" ]
then
	svn copy trunk/ tags/$NEWVERSION1/
	cd $SVNPATH/tags/$NEWVERSION1
	svn commit --username=$SVNUSER --password=$SVNPASS -m "Tagging version $NEWVERSION1"
else
	echo "SVN tag already exists. Do nothing."
fi

echo "Add header image if exists"
cd $SVNPATH
if [ -f "$GITPATH/banner-772x250."* ]
then
	if [ ! -d "$SVNPATH/assets" ]
	then
		mkdir $SVNPATH/assets
	fi

	cp $GITPATH/banner-772x250.* $SVNPATH/assets/ 

	svn status | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2}' | xargs svn add
	svn commit --username=$SVNUSER --password=$SVNPASS -m "add banner image"

fi

echo "Removing temporary directory $SVNPATH"
rm -fr $SVNPATH/

echo "*** FINISHED ***"
