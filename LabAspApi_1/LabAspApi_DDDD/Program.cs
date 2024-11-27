using System.Data;
using LabAspApi.Services;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

// 환경 변수로부터 연결 문자열 가져오기
string? connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// SqlConnection을 위해 서비스 등록
builder.Services.AddScoped<IDbConnection>(db => new SqlConnection(connectionString));

// 기타 서비스 등록
builder.Services.AddControllers();
builder.Services.AddScoped<ProductsService>();
builder.Services.AddScoped<TestService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

app.UseAuthorization();
app.MapControllers();

app.Run();
