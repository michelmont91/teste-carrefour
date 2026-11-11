FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /source
COPY . .
WORKDIR /source/src/WriteService/WriteService.API
RUN dotnet publish WriteService.API.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "WriteService.API.dll"]
