FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019 AS build
WORKDIR /app

# copy csproj and restore as distinct layers
COPY *.sln .
COPY DockerAspNet48/*.csproj ./DockerAspNet48/
COPY DockerAspNet48/*.config ./DockerAspNet48/
RUN nuget restore

# copy everything else and build app
COPY DockerAspNet48/. ./DockerAspNet48/
WORKDIR /app/DockerAspNet48
RUN msbuild /p:Configuration=Release -r:False


FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS runtime
WORKDIR /inetpub/wwwroot
COPY --from=build /app/DockerAspNet48/. ./

COPY DockerAspNet48/Font/. ./Font/
RUN .\Font\InstallFont.ps1
RUN .\Font\AddFonts.ps1