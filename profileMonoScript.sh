#!/bin/bash
# Shell script to profile mono-netcore by running TechEmpower plainText benchmarks.
#
# Need to pass in the configuration of mono-netcore which has to be one of these three:
# * jit
# * jit-llvm
# * aot-llvm
#
# Before running this script, please define the following variables with proper path to directories on your computer
# * MONO_GIT_ROOT - The full path to the root of your mono local repo that you'd like to collect flamegraph from
# * TE_PRJ_DIR - The full path to the TechEmpower benchmark project. You could clone it from https://github.com/aspnet/Benchmarks
# * FLAME_GRAPH_ROOT - The full path to the root of your flamegraph local repo. You could clone it from https://github.com/brendangregg/FlameGraph
# * TRACE_DIR - The full path to the location where you'd like to save perf data and flamegraphs
#
# Usage:
#     ./profileMonoScript.sh jit


echo ">>>>>>>>>>> ${1}"

MONO_GIT_ROOT="/home/yangfan/dotnet_latest/runtime"
TE_PRJ_DIR="/home/yangfan/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks"
FLAME_GRAPH_ROOT="/home/yangfan/FlameGraph"
TRACE_DIR="/home/yangfan/trace"

# Build mono netcore
cd $MONO_GIT_ROOT
export MONO_DEBUG=disable_omit_fp
case $1 in
    jit)
	./build.sh mono+libs -c Release
	echo ">>>>>>>> reached jit case";;
    jit-llvm)
	./build.sh mono+libs -c Release /p:MonoEnableLLVM=true
	echo ">>>>>>>> reached jit-llvm case";;
    aot-llvm)
	./build.sh mono+libs -c Release /p:MonoEnableLLVM=true
	echo ">>>>>>>> reached aot-llvm case";;
esac

# Build and run test app
export BenchmarksTargetFramework=net5.0
export MicrosoftAspNetCoreAppPackageVersion=6.0.0-preview.4.21253.5
export MicrosoftNETCoreAppPackageVersion=6.0.0-preview.4.21253.7
export MONO_ENV_OPTIONS=--jitmap
echo ">>>>>>>>>>MONO_DEBUG is ${MONO_DEBUG}"
if [[ $1 == *"llvm"* ]]; then
    export MONO_ENV_OPTIONS="--llvm --jitmap"
    echo ">>>>>>>>>>> reached llvm condition"
fi

./dotnet.sh publish -c release -r linux-x64 $TE_PRJ_DIR/PlatformBenchmarks.csproj
if [ $1 == "aot-llvm" ]; then
    echo ">>>>>>>>> reached aot-llvm condition"
    PATH="../llvm/usr/bin/:$(PATH)" \
	MONO_ENV_OPTIONS="--aot=llvm,mcpu=native"\
	./dotnet.sh $TE_PRJ_DIR/bin/release/net5.0/linux-x64/PlatformBenchmarks &
fi
./dotnet.sh $TE_PRJ_DIR/bin/release/net5.0/linux-x64/PlatformBenchmarks &

# Wait for the server to start accepting requests
while ! echo exit | nc localhost 8080; do sleep 10; done

# Warm up
wrk --latency -t 8 -d 15 -c 256 --header "Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7" --header "Connection: keep-alive" http://localhost:8080/plaintext

# Get dotnet PID number
pid="$(ps aux | grep -i "dotnet" | grep -v grep | awk '{split($0,a," ");print a[2]}')"
echo ">>>>>>>>>>>>>>>MONO_ENV_OPTIONS is ${MONO_ENV_OPTIONS}"
echo ">>>>>>>>>>>>>>>PID is ${pid}"

# Collect profile data
echo ">>>>>>>>>>>>>>>Start to collect perf data"
cd $TRACE_DIR
perf record -F 99 -p $pid -g -- sleep 20 &
#perf record --call-graph dwarf -p $pid sleep 20 &
wrk --latency -t 8 -d 15 -c 256 --header "Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7" --header "Connection: keep-alive" http://localhost:8080/plaintext
sleep 10
kill $pid

# Create flame graph
echo ">>>>>>>>>>>>>>>Start to create flame graph"
cd $FLAME_GRAPH_ROOT
cp $TRACE_DIR/perf.data .
perf script | ./stackcollapse-perf.pl |./flamegraph.pl > perf.svg
cp perf.svg $TRACE_DIR

echo ">>>>>>>>>>>>>>Done creating flame graph"
