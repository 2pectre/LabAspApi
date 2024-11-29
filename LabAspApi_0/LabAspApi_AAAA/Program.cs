using System.Data;
using LabAspApi.Services;
using Microsoft.Data.SqlClient;
using Microsoft.AspNetCore.HttpOverrides; // ForwardedHeaders 사용을 위한 네임스페이스 추가

var builder = WebApplication.CreateBuilder(args);

// 환경 변수로부터 연결 문자열 가져오기
string? connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// SqlConnection을 위해 서비스 등록
builder.Services.AddScoped<IDbConnection>(db => new SqlConnection(connectionString));

// 기타 서비스 등록
builder.Services.AddControllers();
builder.Services.AddScoped<ProductsService>();
builder.Services.AddScoped<TestService>();

// 여기에서 앱을 빌드한 후에 'app'을 사용할 수 있습니다.
var app = builder.Build();

// Forwarded Headers 미들웨어 사용
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

app.UseAuthorization();
app.MapControllers();

app.Run();
