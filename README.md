# JetGo

JetGo je seminarski rad za predmet Razvoj softvera II. Sistem predstavlja platformu za
pretragu, rezervaciju i placanje letova sa odvojenim administrativnim desktop klijentom,
mobilnom aplikacijom za korisnike, glavnim REST API servisom i posebnim RabbitMQ worker
servisom za asinhrone notifikacije.

## Kratak pregled sistema

Projekt je podijeljen na 4 glavna dijela:

- `API/JetGo.API` - glavni REST API
- `Worker/JetGo.Worker` - pozadinski worker za RabbitMQ obradu
- `Desktop/jetgo_desktop` - Flutter Windows administrativna aplikacija
- `Mobile/jetgo_mobile` - Flutter Android mobilna aplikacija

Pomocni slojevi backenda:

- `API/JetGo.Application` - DTO modeli, request modeli, interfejsi i konstante
- `API/JetGo.Domain` - domenski modeli, enum-i i bazne klase
- `API/JetGo.Infrastructure` - EF Core, Identity, servisi, seed, PayPal, RabbitMQ i ostala infrastruktura

## Implementirane funkcionalnosti

### Backend / API

- JWT autentifikacija i autorizacija
- ASP.NET Identity korisnici i role
- CRUD nad referentnim podacima:
  - drzave
  - gradovi
  - aerodromi
  - aviokompanije
  - destinacije
  - letovi
- pretraga letova sa filterima i paginacijom
- rezervacije sjedista i dodatnog prtljaga
- payment workflow preko PayPal sandbox integracije
- refund workflow sa pravilom 48h prije polaska
- sistemske notifikacije i news modul
- korisnicki profil, promjena lozinke i reset lozinke
- support / korisnicki upiti
- PDF izvjestaji za rezervacije i placanja
- explainable recommender za letove

### Desktop aplikacija

Administrativni moduli:

- kontrolna tabla
- moj profil
- osnovni podaci
- rute i letovi
- rezervacije
- korisnici
- podrska
- novosti
- placanja
- izvjestaji

### Mobilna aplikacija

Korisnicki moduli:

- pregled i filtriranje letova
- detalji leta i rezervacija sjedista
- upravljanje dodatnim prtljagom
- pregled rezervacija
- iniciranje i potvrda placanja
- zahtjev za refund kroz podrsku
- novosti
- notifikacije
- moj profil
- promjena lozinke
- podrska
- preporuke letova

### Asinhroni worker

Worker slusa RabbitMQ queue `jetgo.notifications` i upisuje sistemske notifikacije nakon
relevantnih dogadjaja, npr:

- kreiranje rezervacije
- otkazivanje rezervacije
- evidencija placanja
- refund
- odgovor na support poruku

## Test korisnici

Seed podaci trenutno kreiraju sljedece naloge:

- Desktop admin
  - username: `desktop`
  - password: `test`
- Mobile korisnik
  - username: `mobile`
  - password: `test`
- Dodatni mobile test korisnik
  - username: `mobile2`
  - password: `test`

Role nazivi koji se koriste u sistemu:

- `Admin`
- `User`

## Cisto demo stanje za finalno testiranje

Nakon svjezeg resetovanja baze i ponovnog starta aplikacije seed priprema stanje pogodno za
demonstraciju:

- korisnici:
  - `desktop` / `test`
  - `mobile` / `test`
  - `mobile2` / `test`
- referentni podaci:
  - drzave, gradovi, aerodromi, aviokompanije i destinacije
- letovi:
  - seed letovi `JG100` do `JG105`
  - svi su zakazani za **decembar 2026**
  - svi pocinju bez rezervisanih sjedista
- novosti:
  - dvije objavljene novosti za mobile prikaz
- transakcijski podaci:
  - nema seed rezervacija
  - nema seed placanja
  - nema seed refunda
  - nema seed korisnickih upita podrsci
  - nema seed notifikacija

To znaci da nakon cistog reseta mozes od pocetka testirati:

- kreiranje rezervacija
- dodatni prtljag
- PayPal placanje
- refund
- support tok
- notifikacije
- administraciju ruta, letova i novosti

## Recommender dokumentacija

Posebna dokumentacija recommender sistema nalazi se u fajlu:

- [recommender-dokumentacija.md](recommender-dokumentacija.md)

Dokument opisuje:

- koji se signali koriste
- kako se puni `SearchHistory`
- formulu bodovanja
- objasnjive razloge preporuke
- gdje se logika nalazi u kodu

## Konfiguracija

Pravi `.env` fajl nije pracen kroz Git. Za lokalno pokretanje koristi se sablon:

- [`.env.example`](.env.example)

Za predaju se raw `.env` ne postavlja u GitHub Release build arhivu. Ako je potreban
konfiguracijski fajl sa stvarnim tajnama, koristi se password-protected ZIP arhiva prema
uputama predmeta.

Najbitnije varijable:

- `JETGO_CONNECTION_STRING`
- `JETGO_JWT_ISSUER`
- `JETGO_JWT_AUDIENCE`
- `JETGO_JWT_KEY`
- `JETGO_JWT_EXPIRY_MINUTES`
- `JETGO_SQL_SA_PASSWORD`
- `JETGO_RABBITMQ_DEFAULT_USER`
- `JETGO_RABBITMQ_DEFAULT_PASS`
- `JETGO_RABBITMQ_NOTIFICATIONS_QUEUE`
- `JETGO_PAYPAL_CLIENT_ID`
- `JETGO_PAYPAL_CLIENT_SECRET`
- `JETGO_PAYPAL_RETURN_URL`
- `JETGO_PAYPAL_CANCEL_URL`
- `JETGO_PAYPAL_CURRENCY_CODE`
- `JETGO_PAYPAL_BAM_TO_CURRENCY_RATE`
- `JETGO_SMTP_HOST`
- `JETGO_SMTP_PORT`
- `JETGO_SMTP_USERNAME`
- `JETGO_SMTP_PASSWORD`
- `JETGO_SMTP_USE_SSL`
- `JETGO_SMTP_FROM_EMAIL`
- `JETGO_SMTP_FROM_NAME`
- `JETGO_CORS_ALLOWED_ORIGINS`

Napomena:

- root `.env` koristi se za Docker i lokalni backend
- mobile i desktop citaju API adresu preko `--dart-define=API_BASE_URL=...`

## Pokretanje preko Dockera

### Preduvjeti

- Docker Desktop

### Koraci

1. Kopirati `.env.example` u `.env`
2. Popuniti potrebne vrijednosti
3. Iz root foldera pokrenuti:

```powershell
docker compose up --build
```

### Servisi nakon uspjesnog starta

- Swagger: `http://localhost:5000/swagger`
- RabbitMQ Management UI: `http://localhost:15672`
- Mailpit lokalni email inbox: `http://localhost:8025`
- SQL Server: `localhost,1433`

### Napomene

- API pri startupu automatski radi migracije i seed podataka
- Worker treba ostati podignut ako zelis testirati asinhrone notifikacije
- Docker stack sadrzi:
  - SQL Server
  - RabbitMQ
  - Mailpit lokalni SMTP/email inbox
  - API
  - Worker

### Reset lozinke preko lokalnog email inboxa

Za testiranje zaboravljene lozinke koristi se Mailpit. Backend salje reset token preko SMTP-a
na lokalni inbox, bez potrebe za stvarnim email nalozima.

Tok testiranja:

1. U aplikaciji kliknuti `Zaboravili ste lozinku?`
2. Unijeti email test korisnika, npr. `mobile@jetgo.local`
3. Otvoriti `http://localhost:8025`
4. Otvoriti pristigli email i kopirati reset token
5. U aplikaciji unijeti token, novu lozinku i potvrdu lozinke

### Reset na cisto demo stanje preko Dockera

Ako zelis potpuno svjezu bazu bez starih rezervacija i placanja, iz root foldera pokreni:

```powershell
docker compose down -v
docker compose up -d --build
```

Ovim se brisu Docker volumeni za SQL Server i RabbitMQ, a zatim se pri novom startu:

- ponovo kreira baza
- primijene EF migracije
- ucitaju seed korisnici i seed referentni podaci

Nakon toga Swagger je dostupan na:

- `http://localhost:5000/swagger`

## Lokalno pokretanje bez Dockera

### Preduvjeti

- .NET 8 SDK
- Flutter SDK
- Android Studio / Android Emulator za mobile
- SQL Server ili LocalDB
- RabbitMQ ako testiras worker i notifikacije

### 1. Pokretanje API-ja

```powershell
dotnet run --project API/JetGo.API/JetGo.API.csproj --launch-profile https
```

Lokalne adrese:

- `https://localhost:7161/swagger`
- `http://localhost:5068/swagger`

### 2. Pokretanje Worker servisa

```powershell
dotnet run --project Worker/JetGo.Worker/JetGo.Worker.csproj
```

### 3. Pokretanje desktop aplikacije

Iz root foldera:

```powershell
cd Desktop\jetgo_desktop
C:\src\flutter\bin\flutter.bat run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Ako koristis lokalni HTTPS API umjesto Docker API-ja, prilagodi `API_BASE_URL`.

### 4. Pokretanje mobile aplikacije

Iz root foldera:

```powershell
cd Mobile\jetgo_mobile
C:\src\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Napomene:

- `10.0.2.2` je standardna adresa kojom Android emulator pristupa host masini
- prije pokretanja treba imati aktivan Android emulator

### Reset na cisto demo stanje bez Dockera

Ako radis sa lokalnim SQL Serverom ili LocalDB bazom, najjednostavniji postupak je:

1. obrisati bazu `220035`
2. ponovo pokrenuti API

API ce pri startupu:

- primijeniti sve migracije
- napraviti seed korisnike
- ucitati seed referentne podatke i letove

## Build koraci za pregled rada

### Mobile Android APK

```powershell
cd Mobile\jetgo_mobile
C:\src\flutter\bin\flutter.bat clean
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Generisani APK:

- `Mobile/jetgo_mobile/build/app/outputs/flutter-apk/app-release.apk`

### Desktop Windows build

```powershell
cd Desktop\jetgo_desktop
C:\src\flutter\bin\flutter.bat clean
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat build windows --release --dart-define=API_BASE_URL=http://localhost:5000
```

Generisani Windows build:

- `Desktop/jetgo_desktop/build/windows/x64/runner/Release/`

## Pregled vaznih API ruta

### Autentifikacija i profil

- `POST /api/Auth/login`
- `POST /api/Auth/register`
- `POST /api/Auth/request-password-reset`
- `POST /api/Auth/reset-password`
- `POST /api/Auth/logout`
- `GET /api/Auth/me`
- `GET /api/Profile/me`
- `PUT /api/Profile/me`
- `POST /api/Profile/change-password`

### Letovi, destinacije i preporuke

- `GET /api/Flights`
- `GET /api/Flights/{id}`
- `GET /api/Recommendations/flights`

### Rezervacije i placanja

- `POST /api/Reservations`
- `GET /api/Reservations/my`
- `GET /api/Reservations/{id}`
- `PUT /api/Reservations/{id}/baggage`
- `POST /api/Payments/reservations/{reservationId}/initialize`
- `POST /api/Payments/{id}/confirm`
- `POST /api/Payments/{id}/refund`
- `GET /api/Payments/my`

### Notifikacije, novosti i podrska

- `GET /api/Notifications`
- `GET /api/Notifications/summary`
- `POST /api/Notifications/{id}/read`
- `POST /api/Notifications/read-all`
- `GET /api/News`
- `GET /api/SupportMessages/my`
- `POST /api/SupportMessages`

### Admin moduli

- `GET /api/AdminDashboard/summary`
- `GET /api/Reservations`
- `GET /api/SupportMessages`
- `GET /api/News/admin`
- `GET /api/admin/destinations`
- `GET /api/admin/flights`
- `GET /api/Payments`
- `GET /api/Reports/reservations.pdf`
- `GET /api/Reports/payments.pdf`

## Baza podataka

- naziv baze: `220035`
- DB provider: SQL Server
- EF Core migracije:
  - `API/JetGo.Infrastructure/Persistence/Migrations`

Glavne aplikacijske tabele ukljucuju:

- `Countries`
- `Cities`
- `Airports`
- `Airlines`
- `Destinations`
- `Flights`
- `FlightSeats`
- `Reservations`
- `ReservationItems`
- `Payments`
- `Notifications`
- `NewsArticles`
- `SupportMessages`
- `SearchHistories`
- `UserProfiles`
- `RefreshTokens`
- `RevokedTokens`

Pored navedenih tabela koriste se i ASP.NET Identity tabele.

## PayPal sandbox napomena

Sistem koristi PayPal sandbox za:

- create order
- approval redirect
- server-side capture
- refund

Bitne napomene:

- baza i aplikacija rade u `BAM`, ali se PayPal iznos po potrebi konvertuje u konfigurabilnu valutu
- `initialize` vraca approval URL
- `confirm` vrsi server-side capture
- `refund` koristi stvarno evidentiran naplaceni iznos
- mobile aplikacija prikazuje korake za otvaranje PayPal approval toka i zavrsetak placanja

## Status poslovne logike

Najbitnija pravila trenutno implementirana u sistemu:

- rezervacija automatski prelazi kroz statusni tok
- korisnik moze imati vise rezervacija za isti let
- refund je dozvoljen samo za placenu rezervaciju koja nije refundirana i samo do 48h prije polaska
- rezervacija prelazi u `Completed` nakon dolaska leta
- worker upisuje notifikacije asinhrono nakon bitnih dogadjaja
- recommender koristi stvarne signale iz aplikacije, a ne simulirane podatke

## Korisne napomene za pregled rada

- Za desktop aplikaciju API adresa treba biti `http://localhost:5000`
- Za Android emulator API adresa treba biti `http://10.0.2.2:5000`
- Ako testiras samo backend, dovoljno je otvoriti Swagger
- Ako testiras notifikacije i worker tok, RabbitMQ i worker moraju biti aktivni
- Za placanja je potrebno popuniti validne PayPal sandbox podatke u `.env`
