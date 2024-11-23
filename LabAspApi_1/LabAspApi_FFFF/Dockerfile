# Dockerfile for LabAspApi project

# Use the .NET SDK to build and run the application
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

# Copy project file and restore dependencies
COPY ["LabAspApi.csproj", "./"]
RUN dotnet restore "./LabAspApi.csproj"

# Copy remaining application files and publish
COPY . .
RUN dotnet publish "LabAspApi.csproj" -c Release -o /app/out

# Use ASP.NET runtime image to run the application
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .

ENTRYPOINT ["dotnet", "LabAspApi.dll"]

# Dockerfile ends here
