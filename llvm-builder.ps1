Param( $targets = @(), $clangVersion, $workingDirectory = ".", $msvcVersion = 2013, $platform = 64, $configuration = "Release", $cmakePath, $pythonPath, $gnu32Path )

# $targets = @("SVN", "CMAKE", "MSBUILD")
# $targets = @("SVN", "CMAKE")
$targets = @("CMAKE")


$clangVersion = 350
# $platform = 32



# $cmakePath = "c:/cygwin-x86_64/tmp/cmake-2.8.12.2-win32-x86/bin"
$cmakePath = "c:/cygwin-x86_64/tmp/cmake-3.0.2-win32-x86/bin"
$pythonPath = "c:/Python27"
$gnu32Path = "c:/usr_share_tools/GnuWin32/bin"


$LLVMBuildEnv = @{
    ClangBuildVersion = "trunk";
    CheckoutRepository = "trunk";
    WorkingDir = ".";
    CheckoutRootDir = "";
    BuildDir = $null;

    SVN = @{
    };

    CMAKE = @{
        ExecPath = "";
        PythonPath = "";
        MSVCVersion = "12";
        # Platform = " Win64";
        Platform = "Win64";
        PlatformDir = "msvc-64";
        BuildDir = "build";
        GeneratorName = $null;
        CommandLine = $null;

        CONST = @{
            MSVC = @{
                2013 = "12 2013";
                2012 = "11 2012";
                2010 = "10 2010";
            };
            PLATFORM = @{
                32 = @{
                    Name = $null;
                    Directory = "msvc-32";
                };
                64 = @{
                    Name = "Win64";
                    Directory = "msvc-64";
                };
            };
        };
    };

    BUILD = @{
        Gnu32Path = "";
        MSVCVersion  = "";
        Platform = "x64";
        PlatformDir = "msvc-64";
        Configuration = "Release";
        TargetNameSuffix = "-x86_64";
        VsCmdPrompt = "";
        VsCmdPromptArg = "amd64";
        CommandLine = "";

        CONST = @{
            MSVC = @{
                2013 = "VS120COMNTOOLS";
                2012 = "VS110COMNTOOLS";
                2010 = "VS100COMNTOOLS";
            };
            PLATFORM = @{
                32 = @{
                    Name = "Win32";
                    Directory = "msvc-32";
                    TargetNameSuffix = "-x86_32";
                    VsCmdPromptArg = "x86";
                }
                64 = @{
                    Name = "x64";
                    Directory = "msvc-64";
                    TargetNameSuffix = "-x86_64";
                    VsCmdPromptArg = "amd64";
                };
            };
        };
    }
}


# utilities

function pause()
{
    echo 'Press any key'
    [Console]::ReadKey()
}


function prependToEnvPath( $path )
{
    if ( $path -ne $null )
    {
        $env:PATH = $path + ";" + $env:PATH
    }
}

function appendToEnvPath( $path )
{
    if ( $path -ne $null )
    {
        $env:PATH += ";" + $path
    }
}


function importScriptEnvVariables( $script, $scriptArg )
{
    $temp_file = [IO.Path]::GetTempFileName()

    cmd /c " `"$script`" $scriptArg && set > `"$temp_file`" "

    Get-Content $temp_file | Foreach-Object {
        if( $_ -match "^(.*?)=(.*)$" )
        { 
            Set-Content "env:\$($matches[1])" $matches[2]
        } 
    }

    Remove-Item $temp_file
}



# common funcs

function messageHelp()
{
    echo '$clangVersion designates llvm version number (e.g 33, 34, 35...)'
    echo 'When $clangVersion is empty that will assign trunk.'
    echo '$workingDirectory is working directory.'
    echo 'When $workingDirectory is empty that will assign /tmp.'
    echo 'Cautions! When a checkout-path exist a same name directory, it deletes and creates. '
}



function setupCommonVariables()
{
    # common

    if ( $clangVersion -ne $null )
    {
        $LLVMBuildEnv.ClangBuildVersion = $clangVersion
        $LLVMBuildEnv.CheckoutRepository = "tags/RELEASE_$clangVersion/final"
    }
    else
    {
        $LLVMBuildEnv.ClangBuildVersion = "trunk"
        $LLVMBuildEnv.CheckoutRepository = "trunk"
    }

    $LLVMBuildEnv.CheckoutRootDir = "clang-" + $LLVMBuildEnv.ClangBuildVersion
    $LLVMBuildEnv.WorkingDir = "."

    if ( $workingDirectory -ne $null )
    {
        $LLVMBuildEnv.WorkingDir = $workingDirectory
    }
}

function executeCommon()
{
}


# SVN funcs


function messageCheckoutEnvironment()
{
    echo "clang build target  = " + $LLVMBuildEnv.ClangBuildVersion
    echo "checkout repository = " + $LLVMBuildEnv.CheckoutRepository
    echo "checkout root directory  = " + $LLVMBuildEnv.CheckoutRootDir
    echo "working directory   = " + $LLVMBuildEnv.WorkingDir
}

function setupCheckoutVariables()
{
}

function executeCheckoutBySVN()
{
    pushd $LLVMBuildEnv.WorkingDir

    $checkout_root_dir = $LLVMBuildEnv.CheckoutRootDir

    if ( Test-Path $checkout_root_dir )
    {
        echo "phase:SVN:remove old dir = $checkout_root_dir"
        Remove-Item -path $checkout_root_dir -recurse -force
    }
    while ( Test-Path $checkout_root_dir )
    {
        Start-Sleep -m 500
    }
    New-Item -name $checkout_root_dir -type directory


    # proxy がある場合は ~/.subversion/servers に host と port を指定
    $cmd = "svn"
    $checkout_infos = @(
        @{
            location = $checkout_root_dir;
            repository_url = "http://llvm.org/svn/llvm-project/llvm/" + $LLVMBuildEnv.CheckoutRepository;
            checkout_dir = "llvm"
        }, 
        @{
            location = Join-Path $checkout_root_dir "llvm/tools";
            repository_url = "http://llvm.org/svn/llvm-project/cfe/" + $LLVMBuildEnv.CheckoutRepository;
            checkout_dir = "clang";
        }, 
        @{
            location = Join-Path $checkout_root_dir "llvm/tools/clang/tools";
            repository_url = "http://llvm.org/svn/llvm-project/clang-tools-extra/" + $LLVMBuildEnv.CheckoutRepository;
            checkout_dir = "extra";
        }, 
        @{
            location = Join-Path $checkout_root_dir "llvm/projects";
            repository_url = "http://llvm.org/svn/llvm-project/compiler-rt/" + $LLVMBuildEnv.CheckoutRepository;
            checkout_dir = "compiler-rt";
        }
    )

    foreach ( $info in $checkout_infos )
    {
        pushd $info.location
        $cmd_args = @("co", "--force", $info.repository_url, $info.checkout_dir)
        & $cmd $cmd_args
        # echo $cmd_args
        popd
    }

    popd
}



# cmake funcs

function setupCMakeVariables()
{
    $LLVMBuildEnv.CMAKE.ExecPath = $cmakePath
    $LLVMBuildEnv.CMAKE.PythonPath = $pythonPath

    $const_vars = $LLVMBuildEnv.CMAKE.CONST

    if ( $msvcVersion -ne $null )
    {
        $LLVMBuildEnv.CMAKE.MSVCVersion = $const_vars.MSVC[ $msvcVersion ]
    }

    if ( $platform -ne $null )
    {
        $LLVMBuildEnv.CMAKE.GeneratorName = "Visual Studio " + $LLVMBuildEnv.CMAKE.MSVCVersion

        $platform_option = $const_vars.PLATFORM[ $platform ].Name
        if ( $platform_option -ne $null )
        {
            $LLVMBuildEnv.CMAKE.GeneratorName += " " + $platform_option
        }

        $LLVMBuildEnv.CMAKE.PlatformDir = $const_vars.PLATFORM[ $platform ].Directory
    }

    if ( $LLVMBuildEnv.BuildDir -eq $null )
    {
        $LLVMBuildEnv.BuildDir = "build"
    }
}


function executeCMake()
{
    prependToEnvPath -path $LLVMBuildEnv.CMAKE.ExecPath
    prependToEnvPath -path $LLVMBuildEnv.CMAKE.PythonPath

    pushd $LLVMBuildEnv.WorkingDir
    cd $LLVMBuildEnv.CheckoutRootDir

    # local vars
    $build_dir = $LLVMBuildEnv.BuildDir
    $platform_dir = $LLVMBuildEnv.CMAKE.PlatformDir

    if ( !( Test-Path $build_dir ) )
    {
        New-Item -name $build_dir -type directory
    }
    cd $build_dir

    if ( Test-Path $platform_dir )
    {
        echo "phase:CMAKE:remove old dir = $platform_dir"
        Remove-Item -path $platform_dir -recurse -force
    }
    while ( Test-Path $platform_dir )
    {
        Start-Sleep -m 500
    }
    New-Item -name $platform_dir -type directory

    cd $platform_dir

    $cmd = "cmake"
    $cmd_args = @("-G", $LLVMBuildEnv.CMAKE.GeneratorName, "..\..\llvm")

    & $cmd $cmd_args

    popd
}



# build funcs


function setupBuildVariables()
{
    $LLVMBuildEnv.BUILD.Gnu32Path = $gnu32Path

    # local vars
    $const_vars = $LLVMBuildEnv.BUILD.CONST

    if ( $msvcVersion -ne $null )
    {
        $LLVMBuildEnv.BUILD.MSVCVersion = $const_vars.MSVC[ $msvcVersion ]
    }

    if ( $platform -ne $null )
    {
        $LLVMBuildEnv.BUILD.Platform = $const_vars.PLATFORM[ $platform ].Name
        $LLVMBuildEnv.BUILD.PlatformDir = $const_vars.PLATFORM[ $platform ].Directory
        $LLVMBuildEnv.BUILD.TargetNameSuffix = $const_vars.PLATFORM[ $platform ].TargetNameSuffix
        $LLVMBuildEnv.BUILD.VsCmdPromptArg = $const_vars.PLATFORM[ $platform ].VsCmdPromptArg
    }

    if ( $configuration -ne $null )
    {
        $LLVMBuildEnv.BUILD.Configuration = $configuration
    }

    # $LLVMBuildEnv.BUILD.VsCmdPrompt = [Environment]::GetEnvironmentVariable($LLVMBuildEnv.BUILD.MSVCVersion, 'Machine')
    $env_var = "env:" + $LLVMBuildEnv.BUILD.MSVCVersion
    $LLVMBuildEnv.BUILD.VsCmdPrompt = Get-Content $env_var
    $LLVMBuildEnv.BUILD.VsCmdPrompt += "../../VC/vcvarsall.bat"
}

function executeBuild()
{
    prependToEnvPath -path $LLVMBuildEnv.BUILD.Gnu32Path

    # $script = $LLVMBuildEnv.BUILD.VsCmdPrompt
    # $scriptArg = $LLVMBuildEnv.BUILD.VsCmdPromptArg
    importScriptEnvVariables -script $LLVMBuildEnv.BUILD.VsCmdPrompt -scriptArg $LLVMBuildEnv.BUILD.VsCmdPromptArg

    pushd $LLVMBuildEnv.WorkingDir
    cd $LLVMBuildEnv.CheckoutRootDir
    cd $LLVMBuildEnv.BuildDir
    cd $LLVMBuildEnv.BUILD.PlatformDir

    $cmd = "msbuild"
    $properties = "/p:Platform=" + $LLVMBuildEnv.BUILD.Platform + ";Configuration=" + $LLVMBuildEnv.BUILD.Configuration
    $cmd_args = @("LLVM.sln", $properties, "/maxcpucount", "/fileLogger")

    & $cmd $cmd_args

    popd
}


$phase_infos = @{
    SVN = @{
        setup = {setupCheckoutVariables};
        execute = {executeCheckoutBySVN};
    };
    CMAKE = @{
        setup = {setupCMakeVariables};
        execute = {executeCMake};
    };
    MSBUILD = @{
        setup = {setupBuildVariables};
        execute = {executeBuild};
    };
}




function setupVariables()
{
    setupCommonVariables

    foreach ( $target in $targets )
    {
        $phase = $phase_infos[ $target ]
        if ( $phase -ne $null )
        {
            & $phase.setup
            # Invoke-Command -scriptblock $phase.setup
        }
    }
}

function executeTasks()
{
    executeCommon

    foreach ( $target in $targets )
    {
        $phase = $phase_infos[ $target ]
        if ( $phase -ne $null )
        {
            & $phase.execute
        }
    }
}



setupVariables
executeTasks


# echo $LLVMBuildEnv
# echo $LLVMBuildEnv.SVN
# echo $LLVMBuildEnv.CMAKE
# echo $LLVMBuildEnv.BUILD
# echo $env:Path


pause

