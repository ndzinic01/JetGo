# JetGo

JetGo je seminarski rad za predmet Razvoj softvera II. Trenutno repozitorij sadrzi backend dio sistema za pretragu i rezervaciju letova, sa podrskom za autentifikaciju, rezervacije, placanja, notifikacije, preporuke, PDF izvjestaje i RabbitMQ worker obradu.

## Trenutno stanje projekta

- `API/JetGo.API` - glavni REST API
- `API/JetGo.Application` - DTO, request modeli i servisni interfejsi
- `API/JetGo.Domain` - domenski modeli i enum-i
- `API/JetGo.Infrastructure` - EF Core, Identity, servisi, RabbitMQ publisher i ostala infrastruktura
- `Worker/JetGo.Worker` - pozadinski worker za asinhronu obradu notifikacija iz RabbitMQ queue-a
- `docker-compose.yml` - podizanje SQL Server, RabbitMQ, API i Worker servisa

Frontend folderi `Desktop/` i `Mobile/` postoje u repozitoriju, ali u ovoj fazi fokus je na backendu i infrastrukturi.

## Implementirane backend funkcionalnosti

- JWT autentifikacija i autorizacija
- Identity korisnici i role
- pretraga i detalji letova i destinacija
- rezervacije sa statusnim tokom `Pending -> Confirmed -> Cancelled / Completed`
- payment workflow i refund tok
- sistemske notifikacije i news modul
- korisnicki profil i promjena / reset lozinke
- support message modul
- search history i explainable recommender za letove
- PDF izvjestaji za rezervacije i placanja
- RabbitMQ worker za asinhrono kreiranje notifikacija
- Docker Compose podizanje cijelog backend stacka

## Test korisnici

Obavezni test nalozi koji se seedaju pri pokretanju aplikacije:

- Desktop admin:
  - username: `desktop`
  - password: `test`
- Mobile korisnik:
  - username: `mobile`
  - password: `test`

Role nazivi koji se koriste u sistemu:

- `Admin`
- `User`

## Konfiguracija

Repozitorij ne prati pravi `.env` fajl. Potrebno je koristiti [`.env.example`](.env.example) kao sablon.

Minimalne vrijednosti koje moraju biti popunjene:

- `JETGO_CONNECTION_STRING`
- `JETGO_JWT_ISSUER`
- `JETGO_JWT_AUDIENCE`
- `JETGO_JWT_KEY`
- `JETGO_JWT_EXPIRY_MINUTES`
- `JETGO_SQL_SA_PASSWORD`
- `JETGO_RABBITMQ_DEFAULT_USER`
- `JETGO_RABBITMQ_DEFAULT_PASS`
- `JETGO_RABBITMQ_NOTIFICATIONS_QUEUE`

## Pokretanje preko Dockera

Preduvjeti:

- Docker Desktop

Koraci:

1. Kreirati lokalni `.env` na osnovu `.env.example`
2. Iz root foldera pokrenuti:

```powershell
docker compose up --build
```

Servisi nakon uspjesnog starta:

- Swagger: `http://localhost:5000/swagger`
- RabbitMQ UI: `http://localhost:15672`
- SQL Server: `localhost,1433`

Napomena:

- API pri startupu automatski radi migracije i seed podataka
- Worker je potreban za asinhrone notifikacije

## Lokalno pokretanje bez Dockera

Preduvjeti:

- .NET 8 SDK
- SQL Server ili LocalDB
- RabbitMQ ako se testiraju asinhrone notifikacije

Koraci:

1. U `.env` postaviti lokalni connection string za bazu `220035`
2. Pokrenuti API:

```powershell
dotnet run --project API/JetGo.API/JetGo.API.csproj --launch-profile https
```

3. Po potrebi pokrenuti Worker:

```powershell
dotnet run --project Worker/JetGo.Worker/JetGo.Worker.csproj
```

Lokalne adrese:

- Swagger: `https://localhost:7161/swagger`
- alternativno HTTP: `http://localhost:5068/swagger`

## Korisni endpointi za testiranje

- `POST /api/Auth/login`
- `GET /api/Flights`
- `GET /api/Recommendations/flights`
- `POST /api/Reservations`
- `GET /api/Notifications`
- `GET /api/Reports/reservations.pdf`
- `GET /api/Reports/payments.pdf`

PDF report endpointi zahtijevaju `Admin` korisnika.

## RabbitMQ napomena

Queue koji se trenutno koristi za asinhrone notifikacije:

- `jetgo.notifications`

Worker slusa queue i upisuje sistemske notifikacije u bazu nakon dogadjaja kao sto su:

- kreiranje rezervacije
- potvrda rezervacije
- otkazivanje rezervacije
- potvrda placanja
- refund placanja
- odgovor na support message

## Baza podataka

- naziv baze: `220035`
- backend koristi EF Core i SQL Server
- migracije se nalaze u `API/JetGo.Infrastructure/Persistence/Migrations`

## Napomena o daljem radu

README trenutno opisuje stvarno implementiran backend dio projekta. Kako budu dodavani Flutter desktop i mobile klijenti, README ce biti prosiren i njihovim run/build uputama.
