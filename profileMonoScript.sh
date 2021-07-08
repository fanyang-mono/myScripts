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

MONO_GIT_ROOT=/home/yangfan/dotnet_latest/runtime
BENCHMARKS_GIT_ROOT=/home/yangfan/Benchmarks
TE_PRJ_DIR=/home/yangfan/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks
WRK_DIR=/home/yangfan/wrk
FLAME_GRAPH_ROOT=/home/yangfan/FlameGraph
TRACE_DIR=/home/yangfan/trace
RUNTIMEPACK=$MONO_GIT_ROOT/artifacts/bin/mono/Linux.x64.Release
AOT_OPTIONS=llvm,mcpu=native,llvm-path=$RUNTIMEPACK,mattr=sse4.2,mattr=popcnt,mattr=lzcnt,mattr=bmi,mattr=bmi2,mattr=pclmul,mattr=aes

# Clean up
rm -rf $TE_PRJ_DIR/bin $TE_PRJ_DIR/obj

# Build mono netcore /p:MonoAOTLLVMUseCxx11Abi=true
cd $MONO_GIT_ROOT
export MONO_DEBUG=disable_omit_fp
case $1 in
    jit)
	./build.sh mono+libs -c Release
	echo ">>>>>>>> reached jit case";;
    jit-llvm)
	./build.sh mono+libs -c Release /p:MonoEnableLLVM=true /p:MonoAOTEnableLLVM=true
	echo ">>>>>>>> reached jit-llvm case";;
    aot-llvm)
	./build.sh mono+libs -c Release /p:MonoEnableLLVM=true /p:MonoAOTEnableLLVM=true /p:BuildMonoAotCrossCompiler=true
	echo ">>>>>>>> reached aot-llvm case";;
esac

# Build and run test app
export BenchmarksTargetFramework=net5.0
export MicrosoftAspNetCoreAppPackageVersion=6.0.0-preview.4.21253.5
export MicrosoftNETCoreAppPackageVersion=6.0.0-preview.4.21253.7
export MONO_ENV_OPTIONS="--jitdump --jitmap"
echo ">>>>>>>>>>MONO_DEBUG is ${MONO_DEBUG}"
if [[ $1 == *"llvm"* ]]; then
    export MONO_ENV_OPTIONS="--llvm --jitmap"
    echo ">>>>>>>>>>> reached llvm condition"
fi

./dotnet.sh publish -c Release -r linux-x64 $TE_PRJ_DIR/PlatformBenchmarks.csproj

# Use mono runtime
cp $RUNTIMEPACK/System.Private.CoreLib.dll $TE_PRJ_DIR/bin/Release/net5.0/linux-x64/publish/
cp $RUNTIMEPACK/libcoreclr.so $TE_PRJ_DIR/bin/Release/net5.0/linux-x64/publish/
cp $RUNTIMEPACK/libcoreclr.so.dbg $TE_PRJ_DIR/bin/Release/net5.0/linux-x64/publish/
# cp $RUNTIMEPACK/libmono-component-diagnostics_tracing-static.a $TE_PRJ_DIR/bin/Release/net5.0/linux-x64/

if [ $1 == "aot-llvm" ]; then
    echo ">>>>>>>>> reached aot-llvm condition"
	for assembly in $TE_PRJ_DIR/bin/Release/net5.0/linux-x64/publish/*.dll; do \
		echo "=====" && echo "Starting AOT: $assembly" && echo "=====" && \
		MONO_ENV_OPTIONS=--aot="$AOT_OPTIONS" \
		MONO_PATH=$RUNTIMEPACK \
		$RUNTIMEPACK/cross/linux-x64/mono-aot-cross $assembly
	done
fi
$TE_PRJ_DIR/bin/Release/net5.0/linux-x64/publish/PlatformBenchmarks &

# Wait for the server to start accepting requests
while ! echo exit | nc localhost 8080; do sleep 10; done

# Warm up
# $WRK_DIR/wrk --latency -t 32 -d 15 -c 256 --header "Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7" --header "Connection: keep-alive" http://localhost:8080/plaintext
$WRK_DIR/wrk --latency -t 32 -d 15 -c 512 --header "Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7" --header "Connection: keep-alive" http://localhost:8080/json

# Get dotnet PID number
pid="$(ps aux | grep -i "PlatformBenchmarks" | grep -v grep | awk '{split($0,a," ");print a[2]}')"
echo ">>>>>>>>>>>>>>>MONO_ENV_OPTIONS is ${MONO_ENV_OPTIONS}"
echo ">>>>>>>>>>>>>>>PID is ${pid}"

# Collect profile data
echo ">>>>>>>>>>>>>>>Start to collect perf data"
cd $TRACE_DIR
# dotnet-trace collect -p $pid --format Speedscope &
# perf record -F 99 -p $pid -g -- sleep 20 &
perf record -F 95 -p $pid --call-graph dwarf sleep 20 &
#perf record --call-graph dwarf -p $pid sleep 20 &
# $WRK_DIR/wrk --latency -t 32 -d 15 -c 256 --header "Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7" --header "Connection: keep-alive" http://localhost:8080/plaintext
$WRK_DIR/wrk --latency -t 32 -d 15 -c 512 --header "Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7" --header "Connection: keep-alive" http://localhost:8080/json
sleep 10
kill $pid

# Inject jit dump data
perf inject  --input perf.data --jit --output perf-jit.data

# Create flame graph
echo ">>>>>>>>>>>>>>>Start to create flame graph"
cd $FLAME_GRAPH_ROOT
cp $TRACE_DIR/perf-jit.data .
perf script -i perf-jit.data > perf-data.txt
./stackcollapse-perf.pl perf-data.txt |./flamegraph.pl > perf.svg
cp perf.svg $TRACE_DIR

echo ">>>>>>>>>>>>>>Done creating flame graph"
