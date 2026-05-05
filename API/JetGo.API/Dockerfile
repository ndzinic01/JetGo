FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["API/JetGo.API/JetGo.API.csproj", "API/JetGo.API/"]
COPY ["API/JetGo.Application/JetGo.Application.csproj", "API/JetGo.Application/"]
COPY ["API/JetGo.Domain/JetGo.Domain.csproj", "API/JetGo.Domain/"]
COPY ["API/JetGo.Infrastructure/JetGo.Infrastructure.csproj", "API/JetGo.Infrastructure/"]
RUN dotnet restore "API/JetGo.API/JetGo.API.csproj"
COPY . .
WORKDIR "/src/API/JetGo.API"
RUN dotnet publish "JetGo.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "JetGo.API.dll"]
