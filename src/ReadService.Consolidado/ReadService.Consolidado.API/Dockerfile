FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /source
COPY . .
WORKDIR /source/src/ReadService.Consolidado/ReadService.Consolidado.API
RUN dotnet publish ReadService.Consolidado.API.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "ReadService.Consolidado.API.dll"]
