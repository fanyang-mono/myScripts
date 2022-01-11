#!/bin/bash

# Repos that you need to clone before running this script
# * https://github.com/dotnet/runtime
# * https://github.com/dotnet/performance

export RuntimeRepoRootDir=/home/yangfan/work/dotnet_4/runtime
export MicrobenchmarksRepoRootDir=/home/yangfan/work/performance
export DotnetSdkInstallationScriptDir=/home/yangfan/work

export RELEASE_NUM=7
export CONFIG=Release
export ARCH=arm64
export OS=Linux
export MYDOTNET=$RuntimeRepoRootDir/.dotnet-mono/dotnet
export SdkVerNum=7.0.100-alpha.1.21558.2

export RuntimeRepoRootDir_CLR=/home/yangfan/work/dotnet_3/runtime
export MYDOTNET_CLR=$RuntimeRepoRootDir_CLR/.dotnet-new/dotnet

export Benchmark_to_run=System.Tests.Perf_Char.Char_IsUpper

export Benchmark_fcn=Char_IsUpper

export AOT_repo_root=/home/yangfan/work/runtime

export OriginDir=$PWD

export __ForPerf=0

build_repo()
{
    cd $RuntimeRepoRootDir
    git clean -xdff
    if [ $__ForPerf -eq 1 ]; then
        export MONO_DEBUG=disable_omit_fp
    fi
    ./build.sh mono+libs+clr -c $CONFIG /p:MonoEnableLlvm=true /p:MonoLLVMUseCxx11Abi=true
    src/tests/build.sh generatelayoutonly $CONFIG
    cd $OriginDir
}

patch_mono()
{
    cd $RuntimeRepoRootDir
    if [ -d ".dotnet-mono" ]; then
        echo "Remove existing .dotnet-mono folder..."
        rm -rf .dotnet-mono
    fi
    mkdir $RuntimeRepoRootDir/.dotnet-mono

    # install dotnet sdk
    $DotnetSdkInstallationScriptDir/dotnet-install.sh -Architecture $ARCH -InstallDir $RuntimeRepoRootDir/.dotnet-mono -NoPath -Version $SdkVerNum

    # ./build.sh -subset libs.pretest -configuration $CONFIG -ci -arch $ARCH -testscope innerloop /p:RuntimeArtifactsPath=$RuntimeRepoRootDir/artifacts/bin/mono/$OS.$ARCH.$CONFIG /p:RuntimeFlavor=mono
    # cp -rf $RuntimeRepoRootDir/artifacts/bin/runtime/net$RELEASE_NUM.0-$OS-$CONFIG-$ARCH/* $RuntimeRepoRootDir/artifacts/bin/testhost/net$RELEASE_NUM.0-$OS-$CONFIG-$ARCH/shared/Microsoft.NETCore.App/$RELEASE_NUM.0.0
    # cp -r $RuntimeRepoRootDir/artifacts/bin/testhost/net$RELEASE_NUM.0-$OS-$CONFIG-$ARCH/* $RuntimeRepoRootDir/.dotnet-mono
    # cp $RuntimeRepoRootDir/artifacts/bin/coreclr/$OS.$ARCH.$CONFIG/corerun $RuntimeRepoRootDir/.dotnet-mono/shared/Microsoft.NETCore.App/$RELEASE_NUM.0.0/corerun
    cd $OriginDir
}

get_sdk_new_clr()
{
    mkdir $RuntimeRepoRootDir_CLR/.dotnet-new
    $DotnetSdkInstallationScriptDir/dotnet-install.sh -Architecture $ARCH -InstallDir $RuntimeRepoRootDir_CLR/.dotnet-new -NoPath -Version $SdkVerNum
}

build_microbenchmarks()
{
    echo "Warning: In order to build microbenchmarks successfully, you need to add \";netcoreapp$RELEASE_NUM.0\" to TargetFramework and change TargetFramework to TargetFrameworks in file src/harness/BenchmarkDotNet.Extensions/BenchmarkDotNet.Extensions.csproj"
    cd $MicrobenchmarksRepoRootDir/src/harness/BenchmarkDotNet.Extensions
    $MYDOTNET build -c Release
    cd $OriginDir
}

run_microbenchmarks()
{
    cd $MicrobenchmarksRepoRootDir/src/benchmarks/micro
    export MONO_ENV_OPTIONS="--llvm"
    export PerfCommand=""
    if [ $__ForPerf -eq 1 ]; then
        export MONO_ENV_OPTIONS="--jitdump --jitmap --llvm"
        PerfCommand="perf record -F 999 -g"
        rm perf.data perf-jit.data perf-data.txt
    fi
    # $PerfCommand $MYDOTNET run -c Release -f net$RELEASE_NUM.0  MicroBenchmarks.csproj --filter $Benchmark_to_run --keepfiles --corerun $RuntimeRepoRootDir/.dotnet-mono/shared/Microsoft.NETCore.App/$RELEASE_NUM.0.0/corerun --cli $MYDOTNET --runtimes monoaotllvm --aotcompilerpath $RuntimeRepoRootDir/artifacts/obj/mono/Linux.arm64.Release/out/bin/mono-sgen --customruntimepack $RuntimeRepoRootDir/artifacts/bin/microsoft.netcore.app.runtime.linux-arm64/Release --aotcompilermode llvm
    export PATH=$RuntimeRepoRootDir/.dotnet-mono:$PATH
    dotnet run -c Release -f net$RELEASE_NUM.0  MicroBenchmarks.csproj --filter $Benchmark_to_run --keepfiles --runtimes monoaotllvm --aotcompilerpath $RuntimeRepoRootDir/artifacts/obj/mono/Linux.arm64.Release/out/bin/mono-sgen --customruntimepack $RuntimeRepoRootDir/artifacts/bin/microsoft.netcore.app.runtime.linux-arm64/Release
    cd $OriginDir

    
}

run_microbenchmarks_clr()
{
    cd $MicrobenchmarksRepoRootDir/src/benchmarks/micro
    COMPlus_JitDisasm=$Benchmark_fcn $MYDOTNET_CLR run -c Release -f net$RELEASE_NUM.0 --filter $Benchmark_to_run --corerun $RuntimeRepoRootDir_CLR/artifacts/bin/testhost/net$RELEASE_NUM.0-$OS-$CONFIG-$ARCH/shared/Microsoft.NETCore.App/$RELEASE_NUM.0.0/corerun --cli $MYDOTNET_CLR
    cd $OriginDir
}

aot_compile_helloWorld()
{
    cd $AOT_repo_root/src/mono/sample/HelloWorld
    cp /home/yangfan/work/slow_microbenchmarks/$Benchmark_fcn/Program.cs .
    make clean && make run

    for assembly in $AOT_repo_root/artifacts/bin/HelloWorld/$ARCH/$CONFIG/linux-$ARCH/publish/*.dll; do \
        echo "=====" && echo "Starting AOT: $assembly" && echo "=====" && \
        MONO_PATH="$AOT_repo_root/artifacts/bin/mono/$OS.$ARCH.$CONFIG" \
        MONO_ENV_OPTIONS="--aot=llvm,full,mcpu=native,mattr=crc,mattr=crypto,llvm-path=$AOT_repo_root/artifacts/bin/mono/$OS.$ARCH.$CONFIG" \
        $AOT_repo_root/.dotnet-mono/dotnet $assembly && \
        echo ""; \
    done

    cd $OriginDir
}

run_helloWorld()
{
    MONO_VERBOSE_METHOD=$Benchmark_fcn \
    MONO_ENV_OPTIONS="--llvm" \
    $AOT_repo_root/artifacts/bin/HelloWorld/$ARCH/$CONFIG/linux-$ARCH/publish/HelloWorld
}

post_process_perf_data()
{
    cd $MicrobenchmarksRepoRootDir/src/benchmarks/micro
    perf inject  --input perf.data --jit --output perf-jit.data
    perf script -i perf-jit.data > perf-data.txt
    cd $OriginDir
}

main_fcn()
{
    case "$1" in
        build_repo)
            build_repo
            ;;

        patch_mono)
            patch_mono
            ;;

        get_sdk_new_clr)
            get_sdk_new_clr
            ;;

        build_microbenchmarks)
            build_microbenchmarks
            ;;

        run_microbenchmarks)
            run_microbenchmarks
            ;;

        run_microbenchmarks_clr)
            run_microbenchmarks_clr
            ;;
        
        build_and_run_microbenchmarks)
            build_microbenchmarks
            run_microbenchmarks
            ;;

        aot_compile_helloWorld)
            aot_compile_helloWorld
            ;;

        run_helloWorld)
            run_helloWorld
            ;;

        build_all)
            build_repo
            patch_mono
            build_microbenchmarks
            ;;

        post_perf)
            post_process_perf_data
            ;;

        all)
            build_repo
            patch_mono
            build_microbenchmarks
            run_microbenchmarks
            ;;
    esac
}

# Entrypoint of this script
if [ $# -lt 1 ]; then
    echo "Need to provide one of these strings as an argument
            * build_repo
            * patch_mono
            * build_microbenchmarks
            * run_microbenchmarks
            * build_all
            * all"
elif [ $# -lt 2 ]; then
    main_fcn $1
elif [[ $# == 2 && $2 == "perf" ]]; then
    echo "Collection perf data mode is enabled."
    __ForPerf=1
    main_fcn $1
fi