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
using Microsoft.EntityFrameworkCore;
using Npgsql;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

var builder = WebApplication.CreateBuilder(args);

// Definimos el Resource una sola vez
var environment = Environment.GetEnvironmentVariable("ENV") ?? "dev";
var tenant = Environment.GetEnvironmentVariable("TENANT") ?? "default";
var resource = ResourceBuilder.CreateEmpty()
    .AddService(serviceName: "orders-service", serviceVersion: "1.0.0")
    .AddAttributes(new[] {
        new KeyValuePair<string, object>("deployment.environment", environment),
        new KeyValuePair<string, object>("tenant", tenant)
    });

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("service_name", "orders-service")
    .Enrich.WithProperty("service_version", "1.0.0")
    .Enrich.WithProperty("tenant", tenant)
    .Enrich.WithProperty("ApplicationId", "orders-service")
    .Enrich.WithProperty("ApplicationName", "Orders Service")
    .Enrich.WithProperty("Environment", environment)
    .Enrich.WithMachineName()
    .Enrich.WithThreadId()
    .Enrich.WithProcessId()
    .Enrich.With(new ActivityEnricher())
    .WriteTo.Console(new CompactJsonFormatter())
    .WriteTo.OpenTelemetry(options =>
    {
        options.Endpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT") ?? "http://172.17.0.1:4317";
        options.ResourceAttributes = new Dictionary<string, object>
        {
            { "service.name", "orders-service" },
            { "service.version", "1.0.0" },
            { "deployment.environment", environment },
            { "tenant", tenant }
        };
    })
    .CreateLogger();

builder.Host.UseSerilog();

builder.Services.AddControllers();
builder.Services.AddHttpClient();

// Configurar PostgreSQL con Entity Framework Core
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? "Host=postgres;Port=5432;Database=ordersdb;Username=postgres;Password=postgres123";

builder.Services.AddDbContext<OrdersDbContext>(options =>
    options.UseNpgsql(connectionString));

builder.Services.AddOpenTelemetry()
    // --- TRACES ---
    .WithTracing(tracerProviderBuilder => tracerProviderBuilder
        .SetResourceBuilder(resource)
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddGrpcClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation(o =>
        {
            o.SetDbStatementForText = true;
            o.SetDbStatementForStoredProcedure = true;
        })
        .AddNpgsql()
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri(Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT") ?? "http://172.17.0.1:4317");
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
            options.Endpoint = new Uri(Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT") ?? "http://172.17.0.1:4317");
        }));

// // --- LOGGING ---
// builder.Logging.AddOpenTelemetry(options =>
// {
//     options.SetResourceBuilder(resource);
//     options.IncludeScopes = true;
//     options.ParseStateValues = true;
//     options.IncludeFormattedMessage = true;

//     options.AddOtlpExporter(o =>
//     {
//         o.Endpoint = new Uri("http://otel-collector:4317");
//     });
// });

var app = builder.Build();

// Crear la base de datos y aplicar migraciones al iniciar
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
    try
    {
        db.Database.EnsureCreated();
        Log.Information("Base de datos inicializada correctamente");
    }
    catch (Exception ex)
    {
        Log.Error(ex, "Error al inicializar la base de datos");
    }
}

app.MapControllers();

// --- ORDERS SERVICE ENDPOINTS ---

// Crear una orden
app.MapPost("/api/orders", async (
    [FromBody] CreateOrderRequest request,
    [FromServices] OrdersDbContext db,
    [FromServices] IHttpClientFactory httpClientFactory,
    [FromServices] ILogger<Program> logger) =>
{
    var orderId = Guid.NewGuid().ToString();
    logger.LogInformation("Creando orden {OrderId} para cliente {CustomerId} por un total de {Total}",
        orderId, request.CustomerId, request.Total);

    var orderEntity = new OrderEntity
    {
        OrderId = orderId,
        CustomerId = request.CustomerId,
        Total = request.Total,
        Status = "Pending",
        CreatedAt = DateTime.UtcNow
    };

    db.Orders.Add(orderEntity);
    await db.SaveChangesAsync();

    // Simular tiempo de procesamiento
    await Task.Delay(Random.Shared.Next(50, 200));

    // Llamar al servicio de notificaciones
    try
    {
        var client = httpClientFactory.CreateClient();
        var notificationResponse = await client.PostAsJsonAsync(
            "http://notifications:8082/api/notifications/send",
            new { OrderId = orderId, CustomerId = request.CustomerId, Message = "Order created successfully" }
        );

        if (notificationResponse.IsSuccessStatusCode)
        {
            logger.LogInformation("Notificación enviada exitosamente para orden {OrderId}", orderId);
        }
        else
        {
            logger.LogWarning("Fallo al enviar notificación para orden {OrderId}", orderId);
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Error al enviar notificación para orden {OrderId}", orderId);
    }

    logger.LogInformation("Orden {OrderId} creada exitosamente con estado {Status}", orderId, orderEntity.Status);

    var order = new Order(orderEntity.OrderId, orderEntity.CustomerId, orderEntity.Total, orderEntity.Status);
    return Results.Created($"/api/orders/{orderId}", order);
});

// Obtener todas las órdenes
app.MapGet("/api/orders", async ([FromServices] OrdersDbContext db, ILogger<Program> logger) =>
{
    var ordersFromDb = await db.Orders.ToListAsync();
    logger.LogInformation("Consultando todas las órdenes. Total: {Count}", ordersFromDb.Count);

    var orders = ordersFromDb.Select(o => new Order(o.OrderId, o.CustomerId, o.Total, o.Status)).ToList();
    return Results.Ok(orders);
});

// Obtener una orden por ID
app.MapGet("/api/orders/{id}", async (string id, [FromServices] OrdersDbContext db, ILogger<Program> logger) =>
{
    logger.LogInformation("Consultando orden {OrderId}", id);
    var orderEntity = await db.Orders.FirstOrDefaultAsync(o => o.OrderId == id);

    if (orderEntity == null)
    {
        logger.LogWarning("Orden {OrderId} no encontrada", id);
        return Results.NotFound(new { Message = "Order not found" });
    }

    var order = new Order(orderEntity.OrderId, orderEntity.CustomerId, orderEntity.Total, orderEntity.Status);
    return Results.Ok(order);
});

// Actualizar estado de una orden
app.MapPatch("/api/orders/{id}/status", async (
    string id,
    [FromBody] Dictionary<string, string> statusUpdate,
    [FromServices] OrdersDbContext db,
    [FromServices] ILogger<Program> logger) =>
{
    logger.LogInformation("Actualizando estado de orden {OrderId}", id);
    var orderEntity = await db.Orders.FirstOrDefaultAsync(o => o.OrderId == id);

    if (orderEntity == null)
    {
        logger.LogWarning("Orden {OrderId} no encontrada para actualización", id);
        return Results.NotFound();
    }

    var newStatus = statusUpdate.GetValueOrDefault("status", "Pending");
    orderEntity.Status = newStatus;
    await db.SaveChangesAsync();

    // Simular procesamiento
    await Task.Delay(Random.Shared.Next(30, 100));

    logger.LogInformation("Orden {OrderId} actualizada a estado {Status}", id, newStatus);

    var order = new Order(orderEntity.OrderId, orderEntity.CustomerId, orderEntity.Total, orderEntity.Status);
    return Results.Ok(order);
});

// Health check
app.MapGet("/health", () => Results.Ok(new { Service = "Orders", Status = "healthy" }));

app.Run();

// DbContext
public class OrdersDbContext : DbContext
{
    public OrdersDbContext(DbContextOptions<OrdersDbContext> options) : base(options) { }

    public DbSet<OrderEntity> Orders { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<OrderEntity>(entity =>
        {
            entity.ToTable("orders");
            entity.HasKey(e => e.OrderId);
            entity.Property(e => e.OrderId).HasMaxLength(50);
            entity.Property(e => e.CustomerId).HasMaxLength(50).IsRequired();
            entity.Property(e => e.Total).HasColumnType("decimal(18,2)").IsRequired();
            entity.Property(e => e.Status).HasMaxLength(20).IsRequired();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("CURRENT_TIMESTAMP");
        });
    }
}

// Entidad de base de datos
[Table("orders")]
public class OrderEntity
{
    [Key]
    [MaxLength(50)]
    public string OrderId { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    public string CustomerId { get; set; } = string.Empty;

    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal Total { get; set; }

    [Required]
    [MaxLength(20)]
    public string Status { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}

// Modelos
public record Order(string OrderId, string CustomerId, decimal Total, string Status);
public record CreateOrderRequest(string CustomerId, decimal Total);

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