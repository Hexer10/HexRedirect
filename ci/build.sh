#!/bin/bash
set -ev

VERSION=$1
TAG=$2

echo "Download und extract sourcemod"
cd GameServer
wget "http://www.sourcemod.net/latest.php?version=$VERSION&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo "Give compiler rights for compile"
chmod +x addons/sourcemod/scripting/spcomp

echo "Set plugins version"
for file in addons/sourcemod/scripting/HexRedirect.sp
do
  sed -i "s/<TAG>/$TAG/g" $file > output.txt
  rm output.txt
done

addons/sourcemod/scripting/compile.sh HexRedirect.sp

echo "Remove plugins folder if exists"
if [ -d "addons/sourcemod/plugins" ]; then
  rm -r addons/sourcemod/plugins
fi

echo "Create clean plugins folder"
mkdir -p ../build/GameServer/addons/sourcemod/scripting
mkdir ../build/GameServer/addons/sourcemod/configs
mkdir ../build/GameServer/addons/sourcemod/plugins

echo "Move plugins files to their folder"

mv addons/sourcemod/scripting/HexRedirect.sp ../build/GameServer/addons/sourcemod/scripting
mv addons/sourcemod/scripting/compiled/HexRedirect.smx ../build/GameServer/addons/sourcemod/plugins
mv addons/sourcemod/configs/hexredirect.cfg ../build/GameServer/addons/sourcemod/configs
cd ..

echo "Compress the plugin"
mv LICENSE.md build/
mv WebServer/ build/
cd build/ && zip -9rq HexRedirect.zip GameServer/ WebServer/ LICENSE.md && mv HexRedirect.zip ../

echo "Build done"