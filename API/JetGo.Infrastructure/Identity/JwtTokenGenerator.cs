using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using JetGo.Application.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace JetGo.Infrastructure.Identity;

public sealed class JwtTokenGenerator
{
    private readonly JwtSettings _jwtSettings;

    public JwtTokenGenerator(JwtSettings jwtSettings)
    {
        _jwtSettings = jwtSettings;
    }

    public JwtTokenResult Generate(AppUser user, IReadOnlyCollection<string> roles)
    {
        var now = DateTime.UtcNow;
        var expiresAtUtc = now.AddMinutes(_jwtSettings.ExpiryMinutes);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id),
            new(ClaimTypes.NameIdentifier, user.Id),
            new(JwtRegisteredClaimNames.UniqueName, user.UserName ?? string.Empty),
            new(ClaimTypes.Name, user.UserName ?? string.Empty),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new(ClaimTypes.Email, user.Email ?? string.Empty),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));

        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSettings.Key));
        var signingCredentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);
        var securityToken = new JwtSecurityToken(
            issuer: _jwtSettings.Issuer,
            audience: _jwtSettings.Audience,
            claims: claims,
            notBefore: now,
            expires: expiresAtUtc,
            signingCredentials: signingCredentials);

        return new JwtTokenResult(
            new JwtSecurityTokenHandler().WriteToken(securityToken),
            expiresAtUtc);
    }
}

public readonly record struct JwtTokenResult(string AccessToken, DateTime ExpiresAtUtc);
