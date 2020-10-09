#!/bin/sh

# version: 0.2
# modifications:
#      * Changed the outline
#      * remove the . directory from find output    
#
# version: 0.1
# changelog:
#      * Put in script from reused command


origPath="$PWD"
cd "$origPath"
verifyImport.sh *;
find . -maxdepth 10 -type d -exec echo "{}" \; | grep -v '^.$' | while read entry; do
    if [[ "${entry}"  =~ ^.*\.Spotlight.*$ ||
	      "${entry}"  =~ ^.*\.fseventsd$ ||
	      "${entry}"  =~ ^.*\.Trashes.*$  ]];
    then continue;
    else
	cd "${entry}";
	echo "Starting Verifying $(pwd)";
	verifyImport.sh *;
	echo "Finished Verifying $(pwd)";
	cd "$origPath";
    fi;
done
