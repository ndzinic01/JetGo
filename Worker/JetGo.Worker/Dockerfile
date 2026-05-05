FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["Worker/JetGo.Worker/JetGo.Worker.csproj", "Worker/JetGo.Worker/"]
COPY ["API/JetGo.Application/JetGo.Application.csproj", "API/JetGo.Application/"]
COPY ["API/JetGo.Domain/JetGo.Domain.csproj", "API/JetGo.Domain/"]
COPY ["API/JetGo.Infrastructure/JetGo.Infrastructure.csproj", "API/JetGo.Infrastructure/"]
RUN dotnet restore "Worker/JetGo.Worker/JetGo.Worker.csproj"
COPY . .
WORKDIR "/src/Worker/JetGo.Worker"
RUN dotnet publish "JetGo.Worker.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "JetGo.Worker.dll"]
