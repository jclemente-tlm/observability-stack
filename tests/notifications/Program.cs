using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using Serilog;
using Serilog.Sinks.OpenTelemetry;
using Serilog.Extensions.Hosting;
using Serilog.Formatting.Compact;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

// Configura Serilog como logger principal
var environment = Environment.GetEnvironmentVariable("ENV") ?? "dev";
var tenant = Environment.GetEnvironmentVariable("TENANT") ?? "default";
Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("service_name", "notifications-service")
    .Enrich.WithProperty("service_version", "1.0.0")
    .Enrich.WithProperty("tenant", tenant)
    .Enrich.WithMachineName()
    .Enrich.WithThreadId()
    .Enrich.WithProcessId()
    .Enrich.With(new ActivityEnricher())
    .WriteTo.Console(new CompactJsonFormatter())
    .WriteTo.OpenTelemetry(options =>
    {
        options.Endpoint = "http://otel-collector:4317";
        options.ResourceAttributes = new Dictionary<string, object>
        {
            { "service.name", "notifications-service" },
            { "service.version", "1.0.0" },
            { "deployment.environment", environment },
            { "tenant", tenant }
        };
    })
    .CreateLogger();

builder.Host.UseSerilog();

builder.Services.AddControllers();
builder.Services.AddHttpClient();

// Definimos el Resource una sola vez
var resource = ResourceBuilder.CreateEmpty()
    .AddService(serviceName: "notifications-service", serviceVersion: "1.0.0")
    .AddAttributes(new[] {
        new KeyValuePair<string, object>("deployment.environment", environment),
        new KeyValuePair<string, object>("tenant", tenant)
    });

builder.Services.AddOpenTelemetry()
    // --- TRACES ---
    .WithTracing(tracerProviderBuilder => tracerProviderBuilder
        .SetResourceBuilder(resource)
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddGrpcClientInstrumentation()
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://otel-collector:4317");
        }))

    // --- METRICS ---
    .WithMetrics(metricsProviderBuilder => metricsProviderBuilder
        .SetResourceBuilder(resource)
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddProcessInstrumentation()
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://otel-collector:4317");
        }));

var app = builder.Build();

app.MapControllers();

// --- NOTIFICATIONS SERVICE ENDPOINTS ---

var notifications = new List<Notification>();

// Enviar notificación
app.MapPost("/api/notifications/send", async (
    [FromBody] SendNotificationRequest request,
    [FromServices] ILogger<Program> logger) =>
{
    var notificationId = Guid.NewGuid().ToString();
    logger.LogInformation("Enviando notificación {NotificationId} para orden {OrderId}",
        notificationId, request.OrderId);

    // Simular tiempo de envío
    await Task.Delay(Random.Shared.Next(100, 300));

    // Simular fallo ocasional (10% de probabilidad)
    if (Random.Shared.Next(100) < 10)
    {
        logger.LogError("Fallo al enviar notificación {NotificationId} para orden {OrderId}",
            notificationId, request.OrderId);
        return Results.StatusCode(500);
    }

    var notification = new Notification(
        notificationId,
        request.OrderId ?? "unknown",
        request.CustomerId ?? "unknown",
        request.Message ?? "No message",
        DateTime.UtcNow,
        "Sent"
    );
    notifications.Add(notification);

    logger.LogInformation("Notificación {NotificationId} enviada exitosamente", notificationId);
    return Results.Ok(notification);
});

// Obtener todas las notificaciones
app.MapGet("/api/notifications", (ILogger<Program> logger) =>
{
    logger.LogInformation("Consultando todas las notificaciones. Total: {Count}", notifications.Count);
    return Results.Ok(notifications);
});

// Obtener notificación por ID
app.MapGet("/api/notifications/{id}", (string id, ILogger<Program> logger) =>
{
    logger.LogInformation("Consultando notificación {NotificationId}", id);
    var notification = notifications.FirstOrDefault(n => n.NotificationId == id);

    if (notification == null)
    {
        logger.LogWarning("Notificación {NotificationId} no encontrada", id);
        return Results.NotFound(new { Message = "Notification not found" });
    }

    return Results.Ok(notification);
});

// Obtener notificaciones por OrderId
app.MapGet("/api/notifications/order/{orderId}", (string orderId, ILogger<Program> logger) =>
{
    logger.LogInformation("Consultando notificaciones para orden {OrderId}", orderId);
    var orderNotifications = notifications.Where(n => n.OrderId == orderId).ToList();

    logger.LogInformation("Encontradas {Count} notificaciones para orden {OrderId}",
        orderNotifications.Count, orderId);

    return Results.Ok(orderNotifications);
});

// Health check
app.MapGet("/health", () => Results.Ok(new { Service = "Notifications", Status = "healthy" }));

app.Run();

// Modelos
public record Notification(
    string NotificationId,
    string OrderId,
    string CustomerId,
    string Message,
    DateTime SentAt,
    string Status
);
public record SendNotificationRequest(string? OrderId, string? CustomerId, string? Message);

// Enriquecedor personalizado para incluir trace_id y span_id de OpenTelemetry
public class ActivityEnricher : Serilog.Core.ILogEventEnricher
{
    public void Enrich(Serilog.Events.LogEvent logEvent, Serilog.Core.ILogEventPropertyFactory propertyFactory)
    {
        var activity = Activity.Current;
        if (activity != null)
        {
            logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("trace_id", activity.TraceId.ToString()));
            logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("span_id", activity.SpanId.ToString()));
        }
    }
}