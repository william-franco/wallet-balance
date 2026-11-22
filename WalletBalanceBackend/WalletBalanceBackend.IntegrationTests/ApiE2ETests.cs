using Xunit;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace WalletBalanceBackend.IntegrationTests;

public sealed class ApiE2ETests(CustomWebApplicationFactory factory) : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Register_login_and_transactions_flow_succeeds()
    {
        var email = $"user-{Guid.NewGuid():N}@test.local";
        var register = await _client.PostAsJsonAsync(
            "/api/v1/auth/register",
            new { name = "E2E User", email, password = "Pass123!" });
        Assert.True(register.IsSuccessStatusCode);

        var auth = await register.Content.ReadFromJsonAsync<AuthPayload>();
        Assert.NotNull(auth?.AccessToken);

        _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);

        var createTx = await _client.PostAsJsonAsync(
            "/api/v1/transactions",
            new { amount = 10.5m, merchant = "E2E Store", description = "Test purchase" });
        Assert.True(createTx.IsSuccessStatusCode);

        var listTx = await _client.GetAsync("/api/v1/transactions");
        Assert.True(listTx.IsSuccessStatusCode);
    }

    private sealed record AuthPayload(
        [property: JsonPropertyName("accessToken")] string AccessToken);
}