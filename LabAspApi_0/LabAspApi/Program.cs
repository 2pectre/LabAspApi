using System.Data;
using LabAspApi.Services;
using Microsoft.Data.SqlClient;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets; // Ensure Azure SDK packages are up to date

var builder = WebApplication.CreateBuilder(args);

// > Azure Key Vault
/*
var client = new SecretClient(new Uri($"https://specter.vault.azure.net"), new DefaultAzureCredential());
//var client = new SecretClient(new Uri($"https://specter.vault.azure.net"), new ClientSecretCredential(Environment.GetEnvironmentVariable("AZURE_TENANT_ID"), Environment.GetEnvironmentVariable("AZURE_CLIENT_ID"), Environment.GetEnvironmentVariable("AZURE_CLIENT_SECRET")));

var server = client.GetSecret("Server").Value.Value;
var userId = client.GetSecret("User-Id").Value.Value;
var password = client.GetSecret("Password").Value.Value;

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
connectionString = connectionString?.Replace("{server}", server).Replace("{User-Id}", userId).Replace("{Password}", password);
builder.Services.AddScoped<IDbConnection>(sp => new SqlConnection(connectionString));
*/

//builder.Services.AddScoped<IDbConnection>(sp => new SqlConnection(builder.Configuration.GetConnectionString("DefaultConnection")));

// 환경 변수로부터 연결 문자열 가져오기
string? connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// SqlConnection을 위해 서비스 등록
builder.Services.AddScoped<IDbConnection>(db => new SqlConnection(connectionString));

// > MVC 패턴 Controller 사용 설정
builder.Services.AddControllers();

// > 의존성 주입(DI)
// > AddScoped : 각 요청마다 하나의 인스턴스를 생성하고 요청 내에서는 재사용
// > AddTransient : 요청될 때마다 새로운 인스턴스를 생성하며, 상태 공유 안함
builder.Services.AddScoped<ProductsService>();
builder.Services.AddScoped<TestService>();

var app = builder.Build();

// > 개발 환경 예외 발생 출력 미들웨어 설정
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

// > 라우팅, 인증, 권한 부여 등의 미들웨어 설정
app.UseRouting();
app.UseAuthorization();
app.MapControllers();

//string clientIp = HttpContext.Request.Headers["X-Forwarded-For"].FirstOrDefault() ?? HttpContext.Connection.RemoteIpAddress?.ToString();



// stop_grace_period: 10s 설정은 컨테이너가 종료될 때 최대 10초 동안 애플리케이션이 청소 작업을 수행할 수 있는 시간을 제공합니다.
// SIGTERM 신호를 받으면 ApplicationStopping 이벤트가 호출되고, 이때 모든 리소스를 정리하는 작업이 수행됩니다.
// 모든 청소 작업이 10초 내에 완료되면 즉시 애플리케이션이 종료되며, 만약 10초 안에 완료되지 않으면 Docker는 강제 종료를 수행합니다.
// 따라서, 애플리케이션은 주어진 시간 내에 청소 작업을 마무리하고 안전하게 종료됩니다.
// Add services to the container
/*
builder.Services.AddMemoryCache();
builder.Services.AddHttpClient();

//var app = builder.Build();

// Create logger
var logger = app.Services.GetRequiredService<ILogger<Program>>();

// Create memory cache
var memoryCache = app.Services.GetRequiredService<IMemoryCache>();

// Create HTTP client
var httpClientFactory = app.Services.GetRequiredService<IHttpClientFactory>();
var httpClient = httpClientFactory.CreateClient();

// Example database connection (placeholder)
IDisposable databaseConnection = null; // Replace with actual database connection initialization

// Example file stream (placeholder)
FileStream fileStream = null; // Replace with actual file stream initialization

// Example message queue listener (placeholder)
IDisposable messageQueueListener = null; // Replace with actual message queue listener initialization

// Cancellation token for background tasks
CancellationTokenSource backgroundTaskCancellationTokenSource = new CancellationTokenSource();

// Background task example
Task.Run(async () =>
{
    while (!backgroundTaskCancellationTokenSource.Token.IsCancellationRequested)
    {
        // Simulating background work
        await Task.Delay(1000);
        Console.WriteLine("Background task is running...");
    }
    Console.WriteLine("Background task safely stopped.");
});

// Graceful shutdown handling
app.Lifetime.ApplicationStopping.Register(() =>
{
    Console.WriteLine("Application is stopping...");

    // 클라이언트에게 알림을 보내기 위한 HTTP 요청 (푸시 알림 서버 또는 클라이언트 대상)
    //NotifyClientsOfShutdown();

    // 카운트다운 시작
    int countdown = 10; // 10초 동안 카운트다운
    for (int i = countdown; i > 0; i--)
    {
        Console.WriteLine($"Stopping in {i} seconds...");
        Thread.Sleep(1000); // 1초 대기
    }

    // Graceful shutdown 작업들...
    CleanupResources();
});

void NotifyClientsOfShutdown()
{
}

void CleanupResources()
{
    // 여기에 모든 리소스 정리 작업을 넣습니다.
    // 예: 데이터베이스 연결 닫기, 백그라운드 작업 취소 등
    // Database connection cleanup
    if (databaseConnection != null)
    {
        databaseConnection.Dispose();
        Console.WriteLine("Database connection closed.");
    }

    // File stream cleanup
    if (fileStream != null)
    {
        fileStream.Dispose();
        Console.WriteLine("File stream disposed.");
    }

    // Cancel background tasks
    backgroundTaskCancellationTokenSource.Cancel();
    Console.WriteLine("Background tasks have been requested to cancel.");

    // Message queue listener cleanup
    if (messageQueueListener != null)
    {
        messageQueueListener.Dispose();
        Console.WriteLine("Message queue listener disposed.");
    }

    // HTTP client cleanup
    httpClient.Dispose();
    Console.WriteLine("HTTP client disposed.");

    // Memory cache cleanup
    memoryCache.Dispose();
    Console.WriteLine("Memory cache disposed.");

    // Logging shutdown
    logger.LogInformation("Application is stopping at {time}.", DateTime.UtcNow);
}
*/

// > API 시작
app.Run();

//0