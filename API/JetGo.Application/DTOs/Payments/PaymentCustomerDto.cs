namespace JetGo.Application.DTOs.Payments;

public sealed class PaymentCustomerDto
{
    public string UserId { get; init; } = string.Empty;

    public string Username { get; init; } = string.Empty;

    public string FullName { get; init; } = string.Empty;

    public string Email { get; init; } = string.Empty;
}
