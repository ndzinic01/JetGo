using System.Net;
using System.Net.Mail;
using JetGo.Application.Configuration;
using JetGo.Application.Contracts.Services;
using JetGo.Application.Exceptions;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class SmtpEmailSender : IEmailSender
{
    private readonly SmtpSettings _settings;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(SmtpSettings settings, ILogger<SmtpEmailSender> logger)
    {
        _settings = settings;
        _logger = logger;
    }

    public async Task SendPasswordResetEmailAsync(
        string recipientEmail,
        string recipientName,
        string resetToken,
        CancellationToken cancellationToken = default)
    {
        if (!_settings.IsConfigured)
        {
            throw new ValidationException(
                "Email servis nije konfigurisan.",
                new Dictionary<string, string[]>
                {
                    ["email"] = ["Postavite SMTP vrijednosti u .env prije testiranja reset lozinke."]
                });
        }

        using var message = new MailMessage
        {
            From = new MailAddress(_settings.FromEmail, _settings.FromName),
            Subject = "JetGo reset lozinke",
            Body = BuildPasswordResetBody(recipientName, resetToken),
            IsBodyHtml = false
        };
        message.To.Add(new MailAddress(recipientEmail, recipientName));

        using var smtpClient = new SmtpClient(_settings.Host, _settings.Port)
        {
            EnableSsl = _settings.UseSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network
        };

        if (!string.IsNullOrWhiteSpace(_settings.UserName))
        {
            smtpClient.Credentials = new NetworkCredential(_settings.UserName, _settings.Password);
        }

        try
        {
            await smtpClient.SendMailAsync(message, cancellationToken);
            _logger.LogInformation("Password reset email sent to {RecipientEmail}.", recipientEmail);
        }
        catch (SmtpException exception)
        {
            _logger.LogError(exception, "Password reset email could not be sent to {RecipientEmail}.", recipientEmail);
            throw new ValidationException(
                "Slanje emaila za reset lozinke trenutno nije dostupno.",
                new Dictionary<string, string[]>
                {
                    ["email"] = ["Provjerite da li je SMTP/Mailpit servis pokrenut."]
                });
        }
    }

    private static string BuildPasswordResetBody(string recipientName, string resetToken)
    {
        var displayName = string.IsNullOrWhiteSpace(recipientName) ? "korisnice/korisniku" : recipientName;

        return $"""
               Pozdrav {displayName},

               Zaprimili smo zahtjev za reset lozinke za JetGo nalog.

               Reset token:
               {resetToken}

               Kopirajte cijeli token bez dodatnih razmaka ili preloma linije.
               Token vrijedi 15 minuta. Ako niste trazili reset lozinke, ignorisite ovu poruku.

               JetGo tim
               """;
    }
}
