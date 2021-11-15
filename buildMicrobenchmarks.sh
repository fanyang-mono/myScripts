#!/bin/sh

# Repos that you need to clone before running this script
# * https://github.com/dotnet/runtime
# * https://github.com/dotnet/performance

export RuntimeRepoRootDir=/home/yangfan/work/runtime
export MicrobenchmarksRepoRootDir=/home/yangfan/work/performance

export RELEASE_NUM=7
export CONFIG=Release
export ARCH=arm64
export OS=Linux
export MYDOTNET=$RuntimeRepoRootDir/.dotnet-mono/dotnet

export OriginDir=$PWD

build_repo()
{
    cd $RuntimeRepoRootDir
    ./build.sh mono+libs+clr -c $CONFIG
    src/test/build.sh generatelayoutonly $CONFIG
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
    ./build.sh -subset libs.pretest -configuration $CONFIG -ci -arch $ARCH -testscope innerloop /p:RuntimeArtifactsPath=$RuntimeRepoRootDir/artifacts/bin/mono/$OS.$ARCH.$CONFIG /p:RuntimeFlavor=mono
    cp -rf $RuntimeRepoRootDir/artifacts/bin/runtime/net$RELEASE_NUM.0-$OS-$CONFIG-$ARCH/* $RuntimeRepoRootDir/artifacts/bin/testhost/net$RELEASE_NUM.0-$OS-$CONFIG-$ARCH/shared/Microsoft.NETCore.App/$RELEASE_NUM.0.0
    cp -r $RuntimeRepoRootDir/artifacts/bin/testhost/net$RELEASE_NUM.0-$OS-$CONFIG-$ARCH/* $RuntimeRepoRootDir/.dotnet-mono
    cp $RuntimeRepoRootDir/artifacts/bin/coreclr/$OS.$ARCH.$CONFIG/corerun $RuntimeRepoRootDir/.dotnet-mono/shared/Microsoft.NETCore.App/$RELEASE_NUM.0.0/corerun
    cd $OriginDir
}

build_microbenchmarks()
{
    echo "Warning: In order to build microbenchmarks successfully, you need to add \";netcoreapp$RELEASE_NUM.0\" to TargetFrameworks in file src/harness/BenchmarkDotNet.Extensions/BenchmarkDotNet.Extensions.csproj"
    cd $MicrobenchmarksRepoRootDir/src/harness/BenchmarkDotNet.Extensions
    $MYDOTNET build -c Release
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

        build_microbenchmarks)
            build_microbenchmarks
            ;;

        all)
            build_repo
            path_mono
            build_microbenchmarks
            ;;
    esac
}

# Entrypoint of this script
if [ -z "$1" ]; then
    echo "Need to provide one of these strings as an argument
            * build_repo
            * patch_mono
            * build_microbenchmarks
            * all"
else
    main_fcn $1
fi