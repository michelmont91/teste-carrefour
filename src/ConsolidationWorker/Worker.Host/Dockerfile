FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /source
COPY . .
WORKDIR /source/src/ConsolidationWorker/Worker.Host
RUN dotnet publish Worker.Host.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Worker.Host.dll"]
