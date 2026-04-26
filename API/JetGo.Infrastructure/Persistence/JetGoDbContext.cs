using JetGo.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Persistence;

public sealed class JetGoDbContext : DbContext
{
    public JetGoDbContext(DbContextOptions<JetGoDbContext> options)
        : base(options)
    {
    }

    public DbSet<Airline> Airlines => Set<Airline>();
    public DbSet<Airport> Airports => Set<Airport>();
    public DbSet<City> Cities => Set<City>();
    public DbSet<Country> Countries => Set<Country>();
    public DbSet<Destination> Destinations => Set<Destination>();
    public DbSet<Flight> Flights => Set<Flight>();
    public DbSet<FlightSeat> FlightSeats => Set<FlightSeat>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<ReservationItem> ReservationItems => Set<ReservationItem>();
    public DbSet<SearchHistory> SearchHistories => Set<SearchHistory>();
    public DbSet<SupportMessage> SupportMessages => Set<SupportMessage>();
    public DbSet<UserProfile> UserProfiles => Set<UserProfile>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(JetGoDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}
