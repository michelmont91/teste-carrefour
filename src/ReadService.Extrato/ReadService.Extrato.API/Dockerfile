FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /source
COPY . .
WORKDIR /source/src/ReadService.Extrato/ReadService.Extrato.API
RUN dotnet publish ReadService.Extrato.API.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "ReadService.Extrato.API.dll"]
