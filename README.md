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
- SQL Server: `localhost,1433`

### Napomene

- API pri startupu automatski radi migracije i seed podataka
- Worker treba ostati podignut ako zelis testirati asinhrone notifikacije
- Docker stack sadrzi:
  - SQL Server
  - RabbitMQ
  - API
  - Worker

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

## Korisni endpointi za testiranje

### Autentifikacija i profil

- `POST /api/Auth/login`
- `POST /api/Auth/register`
- `POST /api/Auth/refresh`
- `POST /api/Auth/logout`
- `POST /api/Auth/forgot-password`
- `POST /api/Auth/reset-password`
- `GET /api/Profile`
- `PUT /api/Profile`
- `POST /api/Profile/change-password`

### Letovi, destinacije i preporuke

- `GET /api/Flights`
- `GET /api/Flights/{id}`
- `GET /api/Destinations`
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
- `GET /api/SupportMessages`
- `POST /api/SupportMessages`

### Admin moduli

- `GET /api/AdminDashboard`
- `GET /api/AdminCountries`
- `GET /api/AdminCities`
- `GET /api/AdminAirports`
- `GET /api/AdminAirlines`
- `GET /api/AdminDestinations`
- `GET /api/AdminFlights`
- `GET /api/AdminUsers`
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

## Trenutni status README-a

Ovaj README opisuje trenutno implementirano stanje projekta i pokriva:

- strukturu sistema
- glavne funkcionalnosti
- test korisnike
- Docker pokretanje
- lokalno pokretanje
- build korake
- lokaciju recommender dokumentacije

To ga cini pogodnim kao glavni ulazni dokument za pregled i testiranje seminarskog rada.
