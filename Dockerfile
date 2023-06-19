# escape=`
FROM mcr.microsoft.com/windows:ltsc2019 AS build


# RUNTIME?

ENV `
    # Enable detection of running in a container
    COMPLUS_RUNNING_IN_CONTAINER=1 `
    COMPLUS_NGenProtectedProcess_FeatureEnabled=0

RUN `
    # Install .NET Fx 4.8
    curl -fSLo dotnet-framework-installer.exe https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe `
    && .\dotnet-framework-installer.exe /q `
    && del .\dotnet-framework-installer.exe `
    && powershell Remove-Item -Force -Recurse ${Env:TEMP}\* `
    `
    # Apply latest patch
    && curl -fSLo patch.msu https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2023/05/windows10.0-kb5027124-x64-ndp48_c83d3e555cafd96ceece9619e05cd6fc3ce14a23.msu `
    && mkdir patch `
    && expand patch.msu patch -F:* `
    && del /F /Q patch.msu `
    && dism /Online /Quiet /Add-Package /PackagePath:C:\patch\windows10.0-kb5027124-x64-ndp48.cab `
    && rmdir /S /Q patch `
    `
    # ngen .NET Fx
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "Microsoft.Tpm.Commands, Version=10.0.0.0, Culture=Neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=amd64" `
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen update `
    && %windir%\Microsoft.NET\Framework\v4.0.30319\ngen update

# End RUNTIME

# SDK ? 

ENV `
    # Do not generate certificate
    DOTNET_GENERATE_ASPNET_CERTIFICATE=false `
    # NuGet version to install
    NUGET_VERSION=6.5.0 `
    # Install location of Roslyn
    ROSLYN_COMPILER_LOCATION="C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\Roslyn"

# Install NuGet CLI
RUN mkdir "%ProgramFiles%\NuGet\latest" `
    && curl -fSLo "%ProgramFiles%\NuGet\nuget.exe" https://dist.nuget.org/win-x86-commandline/v%NUGET_VERSION%/nuget.exe `
    && mklink "%ProgramFiles%\NuGet\latest\nuget.exe" "%ProgramFiles%\NuGet\nuget.exe"

# Install VS components
RUN `
    # Install VS Test Agent
    curl -fSLo vs_TestAgent.exe https://aka.ms/vs/17/release/vs_TestAgent.exe `
    && start /w vs_TestAgent --quiet --norestart --nocache --wait --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\TestAgent" `
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" `
    && del vs_TestAgent.exe `
    `
    # Install VS Build Tools
    && curl -fSLo vs_BuildTools.exe https://aka.ms/vs/17/release/vs_BuildTools.exe `
    && start /w vs_BuildTools ^ `
        --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" ^ `
        --add Microsoft.Component.ClickOnce.MSBuild ^ `
        --add Microsoft.Net.Component.4.8.SDK ^ `
        --add Microsoft.NetCore.Component.Runtime.6.0 ^ `
        --add Microsoft.NetCore.Component.Runtime.7.0 ^ `
        --add Microsoft.NetCore.Component.SDK ^ `
        --add Microsoft.VisualStudio.Component.NuGet.BuildTools ^ `
        --add Microsoft.VisualStudio.Component.WebDeploy ^ `
        --add Microsoft.VisualStudio.Web.BuildTools.ComponentGroup ^ `
        --add Microsoft.VisualStudio.Workload.MSBuildTools ^ `
        --quiet --norestart --nocache --wait `
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" `
    && del vs_BuildTools.exe `
    `
    # Trigger dotnet first run experience by running arbitrary cmd
    && "%ProgramFiles%\dotnet\dotnet" help `
    `
    # Workaround for issues with 64-bit ngen
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "%ProgramFiles(x86)%\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\SecAnnotate.exe" `
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "%ProgramFiles(x86)%\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\WinMDExp.exe" `
    `
    # ngen assemblies queued by VS installers
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen update `
    && %windir%\Microsoft.NET\Framework\v4.0.30319\ngen update `
    `
    # Cleanup
    && (for /D %i in ("%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\*") do rmdir /S /Q "%i") `
    && (for %i in ("%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\*") do if not "%~nxi" == "vswhere.exe" del "%~i") `
    && powershell Remove-Item -Force -Recurse "%TEMP%\*" `
    && rmdir /S /Q "%ProgramData%\Package Cache"

# Set PATH in one layer to keep image size down.
RUN powershell setx /M PATH $(${Env:PATH} `
    + \";${Env:ProgramFiles}\NuGet\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\TestAgent\Common7\IDE\CommonExtensions\Microsoft\TestWindow\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\amd64\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft SDKs\ClickOnce\SignTool\")

# Install Targeting Packs
RUN powershell " `
    $ErrorActionPreference = 'Stop'; `
    $ProgressPreference = 'SilentlyContinue'; `
    @('4.0', '4.5.2', '4.6.2', '4.7.2', '4.8', '4.8.1') `
    | %{ `
        Invoke-WebRequest `
            -UseBasicParsing `
            -Uri https://dotnetbinaries.blob.core.windows.net/referenceassemblies/v${_}.zip `
            -OutFile referenceassemblies.zip; `
        Expand-Archive referenceassemblies.zip -DestinationPath \"${Env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\"; `
        Remove-Item -Force referenceassemblies.zip; `
    }"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# END SDK


WORKDIR /app
#COPY DockerAspNet48/Offline/Windows/WinSxS ./WinSxS
#COPY DockerAspNet48/Font/. ./Font/
#RUN .\app\Font\InstallFonts.cmd

# copy csproj and restore as distinct layers
COPY *.sln .
COPY DockerAspNet48/*.csproj ./DockerAspNet48/
COPY DockerAspNet48/*.config ./DockerAspNet48/
RUN nuget restore

# copy everything else and build app
COPY DockerAspNet48/. ./DockerAspNet48/
WORKDIR /app/DockerAspNet48
RUN msbuild /p:Configuration=Release -r:False


FROM mcr.microsoft.com/windows:ltsc2019 AS runtime

# RUNTIME?

ENV `
    # Enable detection of running in a container
    COMPLUS_RUNNING_IN_CONTAINER=1 `
    COMPLUS_NGenProtectedProcess_FeatureEnabled=0

RUN `
    # Install .NET Fx 4.8
    curl -fSLo dotnet-framework-installer.exe https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe `
    && .\dotnet-framework-installer.exe /q `
    && del .\dotnet-framework-installer.exe `
    && powershell Remove-Item -Force -Recurse ${Env:TEMP}\* `
    `
    # Apply latest patch
    && curl -fSLo patch.msu https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2023/05/windows10.0-kb5027124-x64-ndp48_c83d3e555cafd96ceece9619e05cd6fc3ce14a23.msu `
    && mkdir patch `
    && expand patch.msu patch -F:* `
    && del /F /Q patch.msu `
    && dism /Online /Quiet /Add-Package /PackagePath:C:\patch\windows10.0-kb5027124-x64-ndp48.cab `
    && rmdir /S /Q patch `
    `
    # ngen .NET Fx
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "Microsoft.Tpm.Commands, Version=10.0.0.0, Culture=Neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=amd64" `
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen update `
    && %windir%\Microsoft.NET\Framework\v4.0.30319\ngen update

# End RUNTIME

# ASPNET

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment; `
    Enable-WindowsOptionalFeature -online -FeatureName NetFx4Extended-ASPNET45; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HealthAndDiagnostics; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-LoggingLibraries; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestMonitor; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpTracing; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Security; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Performance; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-IIS6ManagementCompatibility; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Metabase; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-BasicAuthentication; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationInit; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIExtensions; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIFilter; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpCompressionStatic; `
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45

RUN Remove-Item -Recurse C:\inetpub\wwwroot\*; `
    Invoke-WebRequest -Uri https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.10/ServiceMonitor.exe -OutFile C:\ServiceMonitor.exe; `
    &$Env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen update; `
    &$Env:windir\Microsoft.NET\Framework\v4.0.30319\ngen update

# Install 2.9.0 Roslyn compilers
RUN Invoke-WebRequest https://api.nuget.org/packages/microsoft.net.compilers.2.9.0.nupkg -OutFile C:\microsoft.net.compilers.2.9.0.zip; `
    Expand-Archive -Path C:\microsoft.net.compilers.2.9.0.zip -DestinationPath C:\RoslynCompilers; `
    Remove-Item C:\microsoft.net.compilers.2.9.0.zip -Force; `
    &$Env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen install C:\RoslynCompilers\tools\csc.exe /ExeConfig:C:\RoslynCompilers\tools\csc.exe | `
    &$Env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen install C:\RoslynCompilers\tools\vbc.exe /ExeConfig:C:\RoslynCompilers\tools\vbc.exe | `
    &$Env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen install C:\RoslynCompilers\tools\VBCSCompiler.exe /ExeConfig:C:\RoslynCompilers\tools\VBCSCompiler.exe | `
    &$Env:windir\Microsoft.NET\Framework\v4.0.30319\ngen install C:\RoslynCompilers\tools\csc.exe /ExeConfig:C:\RoslynCompilers\tools\csc.exe | `
    &$Env:windir\Microsoft.NET\Framework\v4.0.30319\ngen install C:\RoslynCompilers\tools\vbc.exe /ExeConfig:C:\RoslynCompilers\tools\vbc.exe | `
    &$Env:windir\Microsoft.NET\Framework\v4.0.30319\ngen install C:\RoslynCompilers\tools\VBCSCompiler.exe  /ExeConfig:C:\RoslynCompilers\tools\VBCSCompiler.exe

# Install 3.6.0 Roslyn compilers
RUN Invoke-WebRequest https://api.nuget.org/packages/microsoft.net.compilers.3.6.0.nupkg -OutFile C:\microsoft.net.compilers.3.6.0.zip; `
    Expand-Archive -Path C:\microsoft.net.compilers.3.6.0.zip -DestinationPath C:\RoslynCompilers-3.6.0; `
    Remove-Item C:\microsoft.net.compilers.3.6.0.zip -Force; `
    &$Env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen install C:\RoslynCompilers-3.6.0\tools\csc.exe /ExeConfig:C:\RoslynCompilers-3.6.0\tools\csc.exe | `
    &$Env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen install C:\RoslynCompilers-3.6.0\tools\vbc.exe /ExeConfig:C:\RoslynCompilers-3.6.0\tools\vbc.exe | `
    &$Env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen install C:\RoslynCompilers-3.6.0\tools\VBCSCompiler.exe /ExeConfig:C:\RoslynCompilers-3.6.0\tools\VBCSCompiler.exe | `
    &$Env:windir\Microsoft.NET\Framework\v4.0.30319\ngen install C:\RoslynCompilers-3.6.0\tools\csc.exe /ExeConfig:C:\RoslynCompilers-3.6.0\tools\csc.exe | `
    &$Env:windir\Microsoft.NET\Framework\v4.0.30319\ngen install C:\RoslynCompilers-3.6.0\tools\vbc.exe /ExeConfig:C:\RoslynCompilers-3.6.0\tools\vbc.exe | `
    &$Env:windir\Microsoft.NET\Framework\v4.0.30319\ngen install C:\RoslynCompilers-3.6.0\tools\VBCSCompiler.exe  /ExeConfig:C:\RoslynCompilers-3.6.0\tools\VBCSCompiler.exe

ENV ROSLYN_COMPILER_LOCATION=C:\RoslynCompilers-3.6.0\tools

# END ASPNET

WORKDIR /inetpub/wwwroot
COPY --from=build /app/DockerAspNet48/. ./

EXPOSE 80

ENTRYPOINT ["C:\\ServiceMonitor.exe", "w3svc"]

#COPY DockerAspNet48/Font/. ./Font/


#ENTRYPOINT ["powershell.exe", "C:\\inetpub\\wwwroot\\Font\\AddFonts.ps1"]