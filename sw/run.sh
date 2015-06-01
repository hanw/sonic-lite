#/bin/bash
#BUILDCACHE_VERBOSE=1 USE_BUILDCACHE=1 V=1 make build.de5
if [ $# -eq 1 ]; then
	if [ $1 == "de5" ]; then
		USE_BUILDCACHE=1 V=1 make build.de5
	elif [ $1 == "htg4" ]; then
		USE_BUILDCACHE=1 V=1 make build.htg4
    elif [ $1 == "sim" ]; then
		USE_BUILDCACHE=1 V=1 make vsim
	elif [ $1 == "test" ]; then
		scp de5/bin/ubuntu.exe hwang@sonic1:/tmp
		scp de5/bin/ubuntu.exe hwang@sonic2:/tmp
		echo "update remote ubuntu.exe"
		#ssh -n -f hwang@sonic1 '/tmp/ubuntu.exe > /dev/null 2>&1'
		#ssh -n -f hwang@sonic2 '/tmp/ubuntu.exe > /dev/null 2>&1'
	fi
fi
