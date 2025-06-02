#pragma warning disable
using Microsoft.Extensions.Configuration;
using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.local.json", true);

// Define parameters for Azure OpenAI
var azureOpenAIResourceGroup = builder.AddParameterFromConfiguration("AzureOpenAIResourceGroup", "AzureOpenAI:ResourceGroup");
var azureSubscriptionId = builder.AddParameterFromConfiguration("AzureSubscriptionId", "Azure:SubscriptionId");
var azureAIFoundryProject = builder.AddParameterFromConfiguration("AzureAIFoundryProject", "AzureAIFoundry:Project");

// Dependencies ------------------------------
var azureStorage = builder.AddAzureStorage("storage")
    .RunAsEmulator(c =>
    {
        c.WithDataBindMount();
        c.WithLifetime(ContainerLifetime.Persistent);
    });
var blobStorage = azureStorage.AddBlobs("uploads");

IResourceBuilder<IResourceWithConnectionString> openai;

const string llmDeploymentName = "gpt-4.1";

if (builder.ExecutionContext.IsPublishMode)
{
    var openAiResource = builder.AddAzureOpenAI("openai");

    openAiResource.AddDeployment("gpt41", "gpt-4.1", "2025-04-14")
        .WithProperties(resource =>
        {
            resource.SkuCapacity = 100;
            resource.SkuName = "GlobalStandard";
        });

    openAiResource.AddDeployment("text-embedding-3-small", "text-embedding-3-small", "1")
        .WithProperties(resource =>
        {
            resource.SkuCapacity = 20;
            resource.SkuName = "GlobalStandard";
        });

    openai = openAiResource;
}
else
{
    var openAiResource = builder.AddConnectionString("openai");
    openai = openAiResource;
}

// Services ----------------------------------
var mcpServer = builder.AddProject<Projects.AccedeSimple_MCPServer>("mcpserver")
    .WithReference(openai)
    .WithEnvironment("MODEL_NAME", llmDeploymentName)
    .WaitFor(openai);

var localGuide = builder.AddPythonApp("localguide", "../localguide", "main.py")
    .WithHttpEndpoint(targetPort: 8000, port: 80)
    .WithEnvironment("PORT", "8000")
    .WithEnvironment("AZURE_OPENAI_ENDPOINT", openai)
    .WithEnvironment("MODEL_NAME", llmDeploymentName)
    .WithOtlpExporter()
    .WaitFor(openai);

var backendApi = builder.AddProject<Projects.AccedeSimple_Service>("backend")
    .WithReference(openai)
    .WithReference(mcpServer)
    .WithReference(localGuide)
    .WithReference(blobStorage)
    .WithEnvironment("MODEL_NAME", llmDeploymentName)
    // Content safety configuration
    .WithEnvironment("AZURE_SUBSCRIPTION_ID", azureSubscriptionId)
    .WithEnvironment("AZURE_RESOURCE_GROUP", azureOpenAIResourceGroup)
    .WithEnvironment("AZURE_AI_FOUNDRY_PROJECT", azureAIFoundryProject)
    .WaitFor(openai);

var webUi = builder.AddNpmApp("webui", "../webui")
    .WithNpmPackageInstallation()
    .WithEnvironment("BACKEND_URL", backendApi.GetEndpoint("http"))
    .WithExternalHttpEndpoints()
    .WithOtlpExporter()
    .WaitFor(backendApi)
    .PublishAsDockerFile();

if (builder.ExecutionContext.IsPublishMode)
{
    var containerRegistry = builder.AddAzureContainerRegistry("acr");

    // Container apps
    var computeEnv = builder.AddAzureContainerAppEnvironment("cae")
        .WithAzureContainerRegistry(containerRegistry);

    mcpServer.WithComputeEnvironment(computeEnv);
    localGuide.WithComputeEnvironment(computeEnv);
    backendApi.WithComputeEnvironment(computeEnv);
    webUi.WithComputeEnvironment(computeEnv);

    // Kubernetes
    //var computeEnv = builder.AddKubernetesEnvironment("k8s")
    //    .WithAzureContainerRegistry(containerRegistry);

    //mcpServer.WithComputeEnvironment(computeEnv)
    //    .PublishAsKubernetesService(resource =>
    //{
    //    resource.Deployment.Spec.Template.Metadata.Labels.Add("azure.workload.identity/use", "true");
    //});
    ////localGuide.WithComputeEnvironment(computeEnv);
    //backendApi.WithComputeEnvironment(computeEnv);
    //webUi.WithComputeEnvironment(computeEnv);
}

builder.Build().Run();
#pragma warning restore