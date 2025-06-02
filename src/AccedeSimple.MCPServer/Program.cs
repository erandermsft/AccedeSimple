var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

builder.Services.AddMcpServer()
    .WithHttpTransport()
    .WithToolsFromAssembly();

builder.Services.AddChatClient(modelName: Environment.GetEnvironmentVariable("MODEL_NAME") ?? "gpt-4.1");

var app = builder.Build();

app.MapMcp();

app.Run();
