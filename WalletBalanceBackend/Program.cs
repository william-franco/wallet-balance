using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

var jwtSection = builder.Configuration.GetSection("Jwt");
var jwtKey = jwtSection["Key"] ?? throw new InvalidOperationException("Jwt:Key is required.");
var jwtIssuer = jwtSection["Issuer"] ?? "wallet-balance";
var jwtAudience = jwtSection["Audience"] ?? "wallet-balance";
var jwtExpiresMinutes = int.Parse(jwtSection["ExpiresInMinutes"] ?? "60");
var refreshExpiresDays = int.Parse(jwtSection["RefreshExpiresInDays"] ?? "7");

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                if (HttpMethods.IsOptions(context.Request.Method))
                {
                    context.NoResult();
                }
                return Task.CompletedTask;
            }
        };
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ClockSkew = TimeSpan.Zero
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.SetIsOriginAllowed(_ => true)
            .AllowAnyHeader()
            .AllowAnyMethod());
});

builder.Services.AddOpenApi();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

var apiV1 = app.MapGroup("/api/v1");

// --- Auth ---

apiV1.MapPost("/auth/register", async (RegisterRequest request, AppDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(request.Name) ||
        string.IsNullOrWhiteSpace(request.Email) ||
        string.IsNullOrWhiteSpace(request.Password))
    {
        return Results.BadRequest(new { message = "Name, email and password are required." });
    }

    var email = request.Email.Trim().ToLowerInvariant();
    if (await db.Users.AnyAsync(u => u.Email == email))
    {
        return Results.Conflict(new { message = "Email already registered." });
    }

    var user = new User
    {
        Name = request.Name.Trim(),
        Email = email,
        Password = BCrypt.Net.BCrypt.HashPassword(request.Password),
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };

    db.Users.Add(user);
    await db.SaveChangesAsync();

    await SeedWalletForUserAsync(db, user);

    var tokens = await CreateTokenPairAsync(db, user, jwtKey, jwtIssuer, jwtAudience, jwtExpiresMinutes, refreshExpiresDays);
    return Results.Ok(new AuthResponse(tokens.AccessToken, tokens.RefreshToken, UserDto.FromEntity(user)));
})
.WithTags("Auth")
.WithName("Register");

apiV1.MapPost("/auth/login", async (LoginRequest request, AppDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
    {
        return Results.BadRequest(new { message = "Email and password are required." });
    }

    var email = request.Email.Trim().ToLowerInvariant();
    var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email);
    if (user is null || !BCrypt.Net.BCrypt.Verify(request.Password, user.Password))
    {
        return Results.Unauthorized();
    }

    var tokens = await CreateTokenPairAsync(db, user, jwtKey, jwtIssuer, jwtAudience, jwtExpiresMinutes, refreshExpiresDays);
    return Results.Ok(new AuthResponse(tokens.AccessToken, tokens.RefreshToken, UserDto.FromEntity(user)));
})
.WithTags("Auth")
.WithName("Login");

apiV1.MapPost("/auth/refresh", async (RefreshRequest request, AppDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(request.RefreshToken))
    {
        return Results.BadRequest(new { message = "Refresh token is required." });
    }

    var stored = await db.RefreshTokens
        .Include(r => r.User)
        .FirstOrDefaultAsync(r => r.Token == request.RefreshToken && r.RevokedAt == null);

    if (stored is null || stored.ExpiresAt <= DateTime.UtcNow)
    {
        return Results.Unauthorized();
    }

    stored.RevokedAt = DateTime.UtcNow;
    var tokens = await CreateTokenPairAsync(db, stored.User!, jwtKey, jwtIssuer, jwtAudience, jwtExpiresMinutes, refreshExpiresDays);
    await db.SaveChangesAsync();

    return Results.Ok(new TokenResponse(tokens.AccessToken, tokens.RefreshToken));
})
.WithTags("Auth")
.WithName("Refresh");

apiV1.MapPost("/auth/logout", async (RefreshRequest request, AppDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(request.RefreshToken))
    {
        return Results.BadRequest(new { message = "Refresh token is required." });
    }

    var stored = await db.RefreshTokens.FirstOrDefaultAsync(r => r.Token == request.RefreshToken && r.RevokedAt == null);
    if (stored is not null)
    {
        stored.RevokedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
    }

    return Results.NoContent();
})
.WithTags("Auth")
.WithName("Logout");

apiV1.MapGet("/auth/me", async (ClaimsPrincipal user, AppDbContext db) =>
{
    var userId = GetUserId(user);
    if (userId is null) return Results.Unauthorized();

    var entity = await db.Users.FindAsync(userId.Value);
    if (entity is null) return Results.NotFound();

    return Results.Ok(UserDto.FromEntity(entity));
})
.RequireAuthorization()
.WithTags("Auth")
.WithName("GetProfile");

// --- Wallet ---

apiV1.MapGet("/cards/me", async (ClaimsPrincipal user, AppDbContext db) =>
{
    var userId = GetUserId(user);
    if (userId is null) return Results.Unauthorized();

    var card = await db.CreditCards.FirstOrDefaultAsync(c => c.UserId == userId.Value);
    if (card is null) return Results.NotFound(new { message = "No credit card found for this user." });

    return Results.Ok(CardSummaryDto.FromEntity(card));
})
.RequireAuthorization()
.WithTags("Cards")
.WithName("GetMyCard");

apiV1.MapGet("/transactions", async (ClaimsPrincipal user, AppDbContext db, string? month) =>
{
    var userId = GetUserId(user);
    if (userId is null) return Results.Unauthorized();

    if (!TryParseMonthRange(month, out var rangeStart, out var rangeEnd, out var monthError))
    {
        return Results.BadRequest(new { message = monthError });
    }

    var query = db.CardTransactions
        .AsNoTracking()
        .Where(t => t.UserId == userId.Value);

    if (rangeStart is not null && rangeEnd is not null)
    {
        query = query.Where(t => t.OccurredAt >= rangeStart && t.OccurredAt < rangeEnd);
    }

    var items = await query
        .OrderByDescending(t => t.OccurredAt)
        .ToListAsync();

    return Results.Ok(items.Select(TransactionDto.FromEntity));
})
.RequireAuthorization()
.WithTags("Transactions")
.WithName("ListTransactions");

apiV1.MapPost("/transactions", async (TransactionRequest request, ClaimsPrincipal user, AppDbContext db) =>
{
    var userId = GetUserId(user);
    if (userId is null) return Results.Unauthorized();

    if (request.Amount <= 0)
    {
        return Results.BadRequest(new { message = "Amount must be greater than zero." });
    }

    if (string.IsNullOrWhiteSpace(request.Merchant))
    {
        return Results.BadRequest(new { message = "Merchant is required." });
    }

    var card = await db.CreditCards.FirstOrDefaultAsync(c => c.UserId == userId.Value);
    if (card is null)
    {
        return Results.NotFound(new { message = "No credit card found for this user." });
    }

    if (card.CurrentBalance + request.Amount > card.CreditLimit)
    {
        return Results.BadRequest(new { message = "Transaction exceeds available credit." });
    }

    var invoice = await db.Invoices
        .Where(i => i.UserId == userId.Value && i.Status == InvoiceStatus.Open)
        .OrderByDescending(i => i.PeriodStart)
        .FirstOrDefaultAsync();

    if (invoice is null)
    {
        return Results.BadRequest(new { message = "No open invoice found for this user." });
    }

    var transaction = new CardTransaction
    {
        UserId = userId.Value,
        CreditCardId = card.Id,
        InvoiceId = invoice.Id,
        Amount = request.Amount,
        Merchant = request.Merchant.Trim(),
        Description = request.Description?.Trim() ?? string.Empty,
        OccurredAt = DateTime.UtcNow
    };

    db.CardTransactions.Add(transaction);
    card.CurrentBalance += request.Amount;
    invoice.TotalAmount += request.Amount;

    await db.SaveChangesAsync();

    return Results.Created($"/api/v1/transactions/{transaction.Id}", TransactionDto.FromEntity(transaction));
})
.RequireAuthorization()
.WithTags("Transactions")
.WithName("CreateTransaction");

apiV1.MapGet("/invoices/current", async (ClaimsPrincipal user, AppDbContext db) =>
{
    var userId = GetUserId(user);
    if (userId is null) return Results.Unauthorized();

    var (periodStart, periodEnd) = GetUtcMonthBounds(DateTime.UtcNow);

    var invoice = await db.Invoices
        .AsNoTracking()
        .FirstOrDefaultAsync(i =>
            i.UserId == userId.Value &&
            i.Status == InvoiceStatus.Open &&
            i.PeriodStart == periodStart &&
            i.PeriodEnd == periodEnd);

    if (invoice is null)
    {
        invoice = await db.Invoices
            .AsNoTracking()
            .Where(i => i.UserId == userId.Value && i.Status == InvoiceStatus.Open)
            .OrderByDescending(i => i.PeriodStart)
            .FirstOrDefaultAsync();
    }

    return invoice is null
        ? Results.NotFound(new { message = "No open invoice found for the current period." })
        : Results.Ok(InvoiceDto.FromEntity(invoice));
})
.RequireAuthorization()
.WithTags("Invoices")
.WithName("GetCurrentInvoice");

apiV1.MapGet("/invoices", async (ClaimsPrincipal user, AppDbContext db) =>
{
    var userId = GetUserId(user);
    if (userId is null) return Results.Unauthorized();

    var invoices = await db.Invoices
        .AsNoTracking()
        .Where(i => i.UserId == userId.Value)
        .OrderByDescending(i => i.PeriodStart)
        .ToListAsync();

    return Results.Ok(invoices.Select(InvoiceDto.FromEntity));
})
.RequireAuthorization()
.WithTags("Invoices")
.WithName("ListInvoices");

apiV1.MapGet("/analytics/spending-by-merchant", async (ClaimsPrincipal user, AppDbContext db, string? month) =>
{
    var userId = GetUserId(user);
    if (userId is null) return Results.Unauthorized();

    if (!TryParseMonthRange(month, out var rangeStart, out var rangeEnd, out var monthError))
    {
        return Results.BadRequest(new { message = monthError });
    }

    var query = db.CardTransactions
        .AsNoTracking()
        .Where(t => t.UserId == userId.Value);

    if (rangeStart is not null && rangeEnd is not null)
    {
        query = query.Where(t => t.OccurredAt >= rangeStart && t.OccurredAt < rangeEnd);
    }

    var grouped = await query
        .GroupBy(t => t.Merchant)
        .Select(g => new MerchantSpendingDto(g.Key, g.Sum(t => t.Amount)))
        .OrderByDescending(x => x.Total)
        .ToListAsync();

    return Results.Ok(grouped);
})
.RequireAuthorization()
.WithTags("Analytics")
.WithName("SpendingByMerchant");

app.Run();

// --- Helpers ---

static int? GetUserId(ClaimsPrincipal user)
{
    var claim = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue(JwtRegisteredClaimNames.Sub);
    return int.TryParse(claim, out var id) ? id : null;
}

static async Task<(string AccessToken, string RefreshToken)> CreateTokenPairAsync(
    AppDbContext db,
    User user,
    string jwtKey,
    string issuer,
    string audience,
    int expiresMinutes,
    int refreshExpiresDays)
{
    var accessToken = GenerateAccessToken(user, jwtKey, issuer, audience, expiresMinutes);
    var refreshToken = GenerateRefreshToken();

    db.RefreshTokens.Add(new RefreshToken
    {
        UserId = user.Id,
        Token = refreshToken,
        ExpiresAt = DateTime.UtcNow.AddDays(refreshExpiresDays),
        RevokedAt = null
    });

    await db.SaveChangesAsync();
    return (accessToken, refreshToken);
}

static string GenerateAccessToken(User user, string jwtKey, string issuer, string audience, int expiresMinutes)
{
    var claims = new[]
    {
        new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
        new Claim(JwtRegisteredClaimNames.Email, user.Email),
        new Claim(ClaimTypes.Name, user.Name),
        new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
    };

    var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
    var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
    var token = new JwtSecurityToken(
        issuer: issuer,
        audience: audience,
        claims: claims,
        expires: DateTime.UtcNow.AddMinutes(expiresMinutes),
        signingCredentials: credentials);

    return new JwtSecurityTokenHandler().WriteToken(token);
}

static string GenerateRefreshToken()
{
    var bytes = new byte[64];
    RandomNumberGenerator.Fill(bytes);
    return Convert.ToBase64String(bytes);
}

static (DateTime PeriodStart, DateTime PeriodEnd) GetUtcMonthBounds(DateTime utcReference)
{
    var periodStart = new DateTime(utcReference.Year, utcReference.Month, 1, 0, 0, 0, DateTimeKind.Utc);
    var lastDay = DateTime.DaysInMonth(utcReference.Year, utcReference.Month);
    var periodEnd = new DateTime(utcReference.Year, utcReference.Month, lastDay, 23, 59, 59, DateTimeKind.Utc);
    return (periodStart, periodEnd);
}

static bool TryParseMonthRange(
    string? month,
    out DateTime? rangeStart,
    out DateTime? rangeEndExclusive,
    out string? error)
{
    rangeStart = null;
    rangeEndExclusive = null;
    error = null;

    if (string.IsNullOrWhiteSpace(month))
    {
        return true;
    }

    if (!DateTime.TryParseExact(month.Trim(), "yyyy-MM", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
    {
        error = "Month must be in YYYY-MM format.";
        return false;
    }

    rangeStart = new DateTime(parsed.Year, parsed.Month, 1, 0, 0, 0, DateTimeKind.Utc);
    rangeEndExclusive = rangeStart.Value.AddMonths(1);
    return true;
}

static async Task SeedWalletForUserAsync(AppDbContext db, User user)
{
    var card = new CreditCard
    {
        UserId = user.Id,
        CreditLimit = 5000m,
        CurrentBalance = 0m,
        HolderName = user.Name,
        LastFour = "4242",
        Brand = "Visa",
        Expiry = "12/29",
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };

    db.CreditCards.Add(card);
    await db.SaveChangesAsync();

    var (periodStart, periodEnd) = GetUtcMonthBounds(DateTime.UtcNow);

    var invoice = new Invoice
    {
        UserId = user.Id,
        CreditCardId = card.Id,
        PeriodStart = periodStart,
        PeriodEnd = periodEnd,
        DueDate = periodEnd.AddDays(10),
        TotalAmount = 0m,
        Status = InvoiceStatus.Open,
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };

    db.Invoices.Add(invoice);
    await db.SaveChangesAsync();

    var demoTransactions = new (decimal Amount, string Merchant, string Description, int DayOffset)[]
    {
        (129.90m, "Amazon", "Echo Dot smart speaker", 2),
        (32.40m, "Uber", "Airport ride", 5),
        (55.90m, "Netflix", "Monthly subscription", 8),
        (18.75m, "Starbucks", "Morning coffee", 11)
    };

    decimal runningTotal = 0m;
    for (var index = 0; index < demoTransactions.Length; index++)
    {
        var demo = demoTransactions[index];
        var occurredAt = periodStart.AddDays(demo.DayOffset);
        if (occurredAt > DateTime.UtcNow)
        {
            occurredAt = DateTime.UtcNow.AddMinutes(-index * 5);
        }

        var transaction = new CardTransaction
        {
            UserId = user.Id,
            CreditCardId = card.Id,
            InvoiceId = invoice.Id,
            Amount = demo.Amount,
            Merchant = demo.Merchant,
            Description = demo.Description,
            OccurredAt = occurredAt
        };

        db.CardTransactions.Add(transaction);
        runningTotal += demo.Amount;
    }

    card.CurrentBalance = runningTotal;
    invoice.TotalAmount = runningTotal;
    card.UpdatedAt = DateTime.UtcNow;
    invoice.UpdatedAt = DateTime.UtcNow;

    await db.SaveChangesAsync();
}

// --- Entities ---

static class InvoiceStatus
{
    public const string Open = "Open";
    public const string Closed = "Closed";
}

class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<CreditCard> CreditCards => Set<CreditCard>();
    public DbSet<CardTransaction> CardTransactions => Set<CardTransaction>();
    public DbSet<Invoice> Invoices => Set<Invoice>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(e =>
        {
            e.HasIndex(u => u.Email).IsUnique();
        });

        modelBuilder.Entity<RefreshToken>(e =>
        {
            e.HasOne(r => r.User).WithMany().HasForeignKey(r => r.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(r => r.Token).IsUnique();
        });

        modelBuilder.Entity<CreditCard>(e =>
        {
            e.HasOne(c => c.User)
                .WithMany(u => u.CreditCards)
                .HasForeignKey(c => c.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Invoice>(e =>
        {
            e.HasOne(i => i.User)
                .WithMany(u => u.Invoices)
                .HasForeignKey(i => i.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(i => i.CreditCard)
                .WithMany(c => c.Invoices)
                .HasForeignKey(i => i.CreditCardId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<CardTransaction>(e =>
        {
            e.ToTable("CardTransactions");

            e.HasOne(t => t.User)
                .WithMany(u => u.Transactions)
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(t => t.CreditCard)
                .WithMany(c => c.Transactions)
                .HasForeignKey(t => t.CreditCardId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(t => t.Invoice)
                .WithMany(i => i.Transactions)
                .HasForeignKey(t => t.InvoiceId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}

class User
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<CreditCard> CreditCards { get; set; } = [];
    public List<CardTransaction> Transactions { get; set; } = [];
    public List<Invoice> Invoices { get; set; } = [];
}

class RefreshToken
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }
    public string Token { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
}

class CreditCard
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }
    public decimal CreditLimit { get; set; }
    public decimal CurrentBalance { get; set; }
    public string HolderName { get; set; } = string.Empty;
    public string LastFour { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public string Expiry { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<CardTransaction> Transactions { get; set; } = [];
    public List<Invoice> Invoices { get; set; } = [];
}

class CardTransaction
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }
    public int CreditCardId { get; set; }
    public CreditCard? CreditCard { get; set; }
    public int InvoiceId { get; set; }
    public Invoice? Invoice { get; set; }
    public decimal Amount { get; set; }
    public string Merchant { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime OccurredAt { get; set; }
}

class Invoice
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }
    public int CreditCardId { get; set; }
    public CreditCard? CreditCard { get; set; }
    public DateTime PeriodStart { get; set; }
    public DateTime PeriodEnd { get; set; }
    public DateTime DueDate { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = InvoiceStatus.Open;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<CardTransaction> Transactions { get; set; } = [];
}

// --- DTOs ---

record RegisterRequest(string Name, string Email, string Password);
record LoginRequest(string Email, string Password);
record RefreshRequest([property: JsonPropertyName("refreshToken")] string RefreshToken);
record TransactionRequest(decimal Amount, string Merchant, string? Description);

record AuthResponse(
    [property: JsonPropertyName("accessToken")] string AccessToken,
    [property: JsonPropertyName("refreshToken")] string RefreshToken,
    UserDto User);

record TokenResponse(
    [property: JsonPropertyName("accessToken")] string AccessToken,
    [property: JsonPropertyName("refreshToken")] string RefreshToken);

record UserDto(int Id, string Name, string Email, DateTime CreatedAt)
{
    public static UserDto FromEntity(User user) =>
        new(user.Id, user.Name, user.Email, user.CreatedAt);
}

record CardSummaryDto(
    decimal CreditLimit,
    decimal CurrentBalance,
    decimal Available,
    string HolderName,
    string LastFour,
    string Brand,
    string Expiry)
{
    public static CardSummaryDto FromEntity(CreditCard card) =>
        new(
            card.CreditLimit,
            card.CurrentBalance,
            card.CreditLimit - card.CurrentBalance,
            card.HolderName,
            card.LastFour,
            card.Brand,
            card.Expiry);
}

record TransactionDto(
    int Id,
    decimal Amount,
    string Merchant,
    string Description,
    DateTime OccurredAt,
    int CreditCardId,
    int InvoiceId)
{
    public static TransactionDto FromEntity(CardTransaction transaction) =>
        new(
            transaction.Id,
            transaction.Amount,
            transaction.Merchant,
            transaction.Description,
            transaction.OccurredAt,
            transaction.CreditCardId,
            transaction.InvoiceId);
}

record InvoiceDto(
    int Id,
    DateTime PeriodStart,
    DateTime PeriodEnd,
    DateTime DueDate,
    decimal TotalAmount,
    string Status,
    int CreditCardId)
{
    public static InvoiceDto FromEntity(Invoice invoice) =>
        new(
            invoice.Id,
            invoice.PeriodStart,
            invoice.PeriodEnd,
            invoice.DueDate,
            invoice.TotalAmount,
            invoice.Status,
            invoice.CreditCardId);
}

record MerchantSpendingDto(string Merchant, decimal Total);
