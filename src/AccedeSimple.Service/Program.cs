#pragma warning disable
using AccedeSimple.Domain;
using Microsoft.Extensions.AI;
using Microsoft.SemanticKernel;
using AccedeSimple.Service;
using System.Collections.Concurrent;
using AccedeSimple.Service.Services;
using Microsoft.Extensions.VectorData;

var builder = WebApplication.CreateBuilder(args);

// Load configuration
builder.Services.Configure<UserSettings>(builder.Configuration.GetSection("UserSettings"));

// Add state stores
builder.Services.AddSingleton<StateStore>();
builder.Services.AddKeyedSingleton<ConcurrentDictionary<string,List<ChatItem>>>("history");

// Add storage
builder.AddKeyedAzureBlobClient("uploads");

builder.AddServiceDefaults();

builder.Services.AddHttpClient("LocalGuide", c =>
{
    c.BaseAddress = new Uri("https+http://localguide");
});

// Chat message stream for SSE
builder.Services.AddSingleton<ChatStream>();

// In-memory storage for trip requests
builder.Services.AddSingleton<IList<TripRequest>>(new List<TripRequest>());

builder.Services.AddMcpClient();

var kernel = builder.Services.AddKernel();

kernel.Services
    .AddChatClient(modelName: Environment.GetEnvironmentVariable("MODEL_NAME") ?? "gpt-4.1")
    .UseFunctionInvocation();

kernel.Services.AddEmbeddingGenerator(modelName: "text-embedding-3-small");

kernel.Services.AddInMemoryVectorStoreRecordCollection<int, Document>("Documents");
kernel.Services.AddTransient<ProcessService>();
kernel.Services.AddTransient<MessageService>();
kernel.Services.AddTransient<SearchService>();

builder.Services.AddTravelProcess();

var app = builder.Build();

var k = app.Services.GetRequiredService<Kernel>();
var collection = k.GetRequiredService<VectorStoreCollection<int, Document>>();
var IngestionService = new IngestionService(collection);
await IngestionService.IngestAsync(Path.Combine(AppContext.BaseDirectory, "docs"));

app.MapEndpoints();

app.Run();

public class UserSettings
{
    public string UserId { get; set; }
    public string AdminUserId { get; set; }

}