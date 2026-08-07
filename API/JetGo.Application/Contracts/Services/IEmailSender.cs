namespace JetGo.Application.Contracts.Services;

public interface IEmailSender
{
    Task SendPasswordResetEmailAsync(
        string recipientEmail,
        string recipientName,
        string resetToken,
        CancellationToken cancellationToken = default);
}
